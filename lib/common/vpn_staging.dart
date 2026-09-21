import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'profile_store.dart';
import 'vpn_configuration.dart';
import 'vpn_intake.dart';
import 'yaml.dart';

class VpnDownload {
  const VpnDownload(this.bytes, {this.filename, this.subscriptionInfo});

  final List<int> bytes;
  final String? filename;
  final SubscriptionInfo? subscriptionInfo;
}

typedef VpnResourceFetch =
    Future<VpnDownload> Function(
      String url,
      Map<String, List<String>> headers,
      CancelToken cancel,
    );

typedef VpnLocalResource =
    Future<List<int>> Function(
      String section,
      String name,
      Map<String, dynamic> definition,
    );

class VpnLocalResourceUnavailable implements Exception {
  const VpnLocalResourceUnavailable();
}

class VpnPreparedCandidate {
  const VpnPreparedCandidate({
    required this.profile,
    required this.prepared,
    required this.selectedMap,
    this.testUrl,
  });

  final Profile profile;
  final PreparedConfigRef prepared;
  final Map<String, String> selectedMap;
  final String? testUrl;
}

class VpnCandidateStager {
  const VpnCandidateStager({
    required this.store,
    required this.fetch,
    required this.prepare,
    required this.discard,
  });

  final ProfileGenerationStore store;
  final VpnResourceFetch fetch;
  final Future<PreparedConfigResult> Function(PrepareConfigParams) prepare;
  final Future<bool> Function(PreparedConfigRef) discard;

  static const geoResources = {
    'GeoSite.dat': (GeoResource.GEOSITE, 'geosite'),
    'GeoIP.dat': (GeoResource.GEOIP, 'geoip'),
    'Country.mmdb': (GeoResource.MMDB, 'mmdb'),
    'ASN.mmdb': (GeoResource.ASN, 'asn'),
  };

  Future<VpnPreparedCandidate> stage({
    required Profile profile,
    required List<int> source,
    required int revision,
    required String testUrl,
    required CancelToken cancel,
    required void Function() checkCurrent,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    overrides,
    VpnLocalResource? localResource,
    bool localOnly = false,
    bool recordFetchTime = true,
    bool migrateSelection = false,
    Set<String>? refreshResources,
    Profile? committed,
    Map<String, List<int>> resources = const {},
  }) async {
    checkCurrent();
    final sourceBytes = List<int>.unmodifiable(source);
    final generation = await store.allocate();
    PreparedConfigRef? handle;
    var accepted = false;
    try {
      await store.write(generation, 'source.yaml', sourceBytes);
      for (final resource in resources.entries) {
        if (!geoResources.containsKey(resource.key)) {
          throw const FormatException('Unexpected staged resource');
        }
        await store.write(generation, resource.key, resource.value);
      }
      final decoded = loadYaml(utf8.decode(sourceBytes));
      if (decoded is! Map) {
        throw const FormatException('Configuration must be a mapping');
      }
      final raw = await overrides(
        jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>,
      );
      checkCurrent();
      final refreshedAt = DateTime.now().toUtc();
      final schedule = _providerSchedule(
        raw,
        profile,
        refreshedAt,
        localOnly,
        refreshResources,
      );
      await _stageProviders(
        generation,
        raw,
        cancel,
        checkCurrent,
        localResource,
        localOnly,
        refreshResources,
      );
      await store.write(
        generation,
        'candidate.yaml',
        utf8.encode(yaml.encode(raw)),
      );
      final downloaded = <String>{};
      Future<PreparedConfigResult> load({required bool probe}) async {
        while (true) {
          checkCurrent();
          try {
            return await prepare(
              PrepareConfigParams(
                generation: generation,
                revision: revision,
                probe: probe ? true : null,
              ),
            );
          } on CoreMethodException catch (error) {
            final details = error.details;
            final name = details is Map ? details['resource'] : null;
            final resource = geoResources[name];
            if (error.code != 'resource_required' ||
                name is! String ||
                resource == null ||
                !downloaded.add(name)) {
              rethrow;
            }
            final configured = raw['geox-url'];
            final url = configured is Map ? configured[resource.$2] : null;
            final cached = File(p.join(store.home.path, name));
            final List<int> bytes;
            if (await FileSystemEntity.type(cached.path, followLinks: false) ==
                FileSystemEntityType.file) {
              bytes = await cached.readAsBytes();
            } else {
              if (localOnly) {
                throw const VpnLocalResourceUnavailable();
              }
              bytes = (await fetch(
                _httpUrl(url ?? defaultGeoXUrl[resource.$1]),
                const {},
                cancel,
              )).bytes;
            }
            checkCurrent();
            await store.write(generation, 'geo/$name', bytes);
          }
        }
      }

      final probe = await load(probe: true);
      handle = PreparedConfigRef(handle: probe.handle, revision: revision);
      checkCurrent();
      _checkResult(probe, generation, revision);
      final VpnConfiguration configuration = buildVpnConfiguration(
        source: raw,
        catalog: probe.servers,
        generation: generation,
        testUrl: testUrl,
        routing: profile.snapshot.routing,
        selection: migrateSelection
            ? legacyVpnSelection(profile, probe.servers, raw)
            : profile.snapshot.selection,
        advancedMode: profile.snapshot.advancedMode,
        advancedSelections: profile.selectedMap,
      );
      await discard(handle);
      handle = null;
      checkCurrent();
      await store.write(
        generation,
        'effective.yaml',
        utf8.encode(yaml.encode(configuration.effective)),
      );
      final result = await load(probe: false);
      handle = PreparedConfigRef(handle: result.handle, revision: revision);
      checkCurrent();
      _checkResult(result, generation, revision);
      if (jsonEncode(result.servers) != jsonEncode(probe.servers)) {
        throw StateError('Server inventory changed during preparation');
      }
      final candidate = profile.copyWith(
        lastUpdateDate: recordFetchTime
            ? DateTime.fromMillisecondsSinceEpoch(
                DateTime.now().millisecondsSinceEpoch ~/
                    Duration.millisecondsPerSecond *
                    Duration.millisecondsPerSecond,
              )
            : profile.lastUpdateDate,
        snapshot: profile.snapshot.copyWith(
          revision: revision,
          generation: generation,
          selection: configuration.selection,
          managedGroups: configuration.groups,
          servers: configuration.servers,
          providerRefresh: schedule,
        ),
      );
      await store.seal(candidate);
      checkCurrent();
      accepted = true;
      return VpnPreparedCandidate(
        profile: candidate,
        prepared: handle,
        selectedMap: configuration.selectedMap,
        testUrl: testUrl,
      );
    } finally {
      if (!accepted) {
        try {
          if (handle != null) await discard(handle);
        } finally {
          await store.discard(generation, committed: committed);
        }
      }
    }
  }

  Future<void> _stageProviders(
    String generation,
    Map<String, dynamic> raw,
    CancelToken cancel,
    void Function() checkCurrent,
    VpnLocalResource? localResource,
    bool localOnly,
    Set<String>? refreshResources,
  ) async {
    final pending = <Future<void> Function()>[];
    for (final section in ['proxy-providers', 'rule-providers']) {
      final definitions = raw[section];
      if (definitions == null) continue;
      if (definitions is! Map) {
        throw const FormatException('Provider definitions must be a mapping');
      }
      for (final entry in definitions.entries) {
        final definition = entry.value;
        if (entry.key is! String || definition is! Map<String, dynamic>) {
          throw const FormatException('Invalid provider definition');
        }
        final name = entry.key as String;
        if (definition['type'] == 'inline') continue;
        pending.add(() async {
          checkCurrent();
          final List<int> bytes;
          final cached =
              localOnly ||
              (refreshResources != null &&
                  !refreshResources.contains('$section/$name'));
          if (cached && localResource != null) {
            bytes = await localResource(section, name, definition);
          } else if (!cached && definition['type'] == 'http') {
            final response = await fetch(
              _httpUrl(definition['url']),
              _headers(definition['header']),
              cancel,
            );
            bytes = response.bytes;
          } else if (definition['type'] == 'file' && localResource != null) {
            bytes = await localResource(section, name, definition);
          } else {
            throw const FormatException(
              'Provider has no usable resource source',
            );
          }
          checkCurrent();
          final key = sha256.convert(utf8.encode(name)).toString();
          final relative = 'providers/$section/$key';
          await store.write(generation, relative, bytes);
          definition['path'] = store.resource(generation, relative).path;
        });
      }
    }
    var index = 0;
    await Future.wait(
      List.generate(pending.length.clamp(0, 4), (_) async {
        while (index < pending.length) {
          await pending[index++]();
        }
      }),
    );
  }

  static List<VpnProviderRefresh> _providerSchedule(
    Map<String, dynamic> raw,
    Profile profile,
    DateTime now,
    bool localOnly,
    Set<String>? refreshResources,
  ) {
    final previous = {
      for (final entry in profile.snapshot.providerRefresh) entry.key: entry,
    };
    final schedule = <VpnProviderRefresh>[];
    for (final section in ['proxy-providers', 'rule-providers']) {
      final definitions = raw[section];
      if (definitions is! Map) continue;
      for (final entry in definitions.entries) {
        final definition = entry.value;
        if (definition is! Map || definition['type'] != 'http') continue;
        final interval = definition['interval'];
        if (interval is! int || interval <= 0) continue;
        final key = '$section/${entry.key}';
        final fetched =
            !localOnly &&
            (refreshResources == null || refreshResources.contains(key));
        schedule.add(
          VpnProviderRefresh(
            section: section,
            name: entry.key as String,
            interval: interval,
            lastUpdate: fetched
                ? now
                : previous[key]?.lastUpdate ?? profile.lastUpdateDate,
          ),
        );
      }
    }
    return schedule;
  }

  static void _checkResult(
    PreparedConfigResult result,
    String generation,
    int revision,
  ) {
    if (result.generation != generation ||
        result.revision != revision ||
        result.handle.isEmpty) {
      throw StateError('Core returned a stale preparation');
    }
  }

  static String _httpUrl(Object? value) {
    if (value is! String) throw const FormatException('Missing resource URL');
    final parsed = VpnUrlIntake.parse(value);
    if (parsed is! VpnUrlAccepted ||
        !RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
      throw const FormatException('Invalid resource URL');
    }
    return parsed.url;
  }

  static Map<String, List<String>> _headers(Object? value) {
    if (value == null) return const {};
    if (value is! Map) throw const FormatException('Invalid provider headers');
    return value.map((key, values) {
      if (key is! String ||
          values is! List ||
          values.any((item) => item is! String)) {
        throw const FormatException('Invalid provider header');
      }
      return MapEntry(key, values.cast<String>());
    });
  }
}
