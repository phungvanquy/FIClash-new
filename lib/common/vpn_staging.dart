import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'profile_store.dart';
import 'constant.dart';
import 'vpn_configuration.dart';
import 'vpn_intake.dart';
import 'vpn_import_progress.dart';
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

Future<List<int>> _bundledGeodata(String name) async {
  final asset = switch (name) {
    'GeoSite.dat' => GEOSITE,
    'GeoIP.dat' => GEOIP,
    'Country.mmdb' => MMDB,
    'ASN.mmdb' => ASN,
    _ => throw const FormatException('Unknown geodata resource'),
  };
  final data = await rootBundle.load('assets/data/$asset');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    this.clock = DateTime.now,
    this.bundledGeodata = _bundledGeodata,
  });

  final ProfileGenerationStore store;
  final VpnResourceFetch fetch;
  final Future<PreparedConfigResult> Function(PrepareConfigParams) prepare;
  final Future<bool> Function(PreparedConfigRef) discard;
  final DateTime Function() clock;
  final Future<List<int>> Function(String name) bundledGeodata;

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
    VpnProgressCallback? onProgress,
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
        await store.write(generation, 'geo/${resource.key}', resource.value);
      }
      final decoded = loadYaml(utf8.decode(sourceBytes));
      if (decoded is! Map) {
        throw const FormatException('Configuration must be a mapping');
      }
      final raw = await overrides(
        jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>,
      );
      checkCurrent();
      void progress(VpnImportProgress value) {
        try {
          onProgress?.call(value);
        } catch (_) {}
      }

      String geoUrl(String name) {
        final resource = geoResources[name]!;
        final configured = raw['geox-url'];
        return _httpUrl(
          (configured is Map ? configured[resource.$2] : null) ??
              defaultGeoXUrl[resource.$1],
        );
      }

      final geoMetadata = <String, Object>{
        for (final name in resources.keys)
          name: _geoMetadata(
            geoUrl(name),
            DateTime.fromMillisecondsSinceEpoch(0),
          ),
      };
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
        progress,
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
          progress(const VpnImportProgress(VpnImportStep.validation));
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
            progress(const VpnImportProgress(VpnImportStep.geodata));
            final url = geoUrl(name);
            final cachedResource = await _cachedGeodata(
              committed,
              name,
              url,
              raw['geo-update-interval'],
              localOnly,
            );
            final cached = File(p.join(store.home.path, name));
            final List<int> bytes;
            final DateTime fetchedAt;
            if (cachedResource != null) {
              (bytes, fetchedAt) = cachedResource;
            } else if (!localOnly &&
                committed == null &&
                url == defaultGeoXUrl[resource.$1]) {
              bytes = await bundledGeodata(name);
              fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
            } else if (localOnly &&
                committed?.snapshot.generation == null &&
                await FileSystemEntity.type(cached.path, followLinks: false) ==
                    FileSystemEntityType.file) {
              bytes = await cached.readAsBytes();
              fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
            } else {
              if (localOnly) {
                throw const VpnLocalResourceUnavailable();
              }
              bytes = (await fetch(url, const {}, cancel)).bytes;
              fetchedAt = clock();
            }
            checkCurrent();
            await store.write(generation, 'geo/$name', bytes);
            geoMetadata[name] = _geoMetadata(url, fetchedAt);
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
      progress(const VpnImportProgress(VpnImportStep.saving));
      if (geoMetadata.isNotEmpty) {
        await store.write(
          generation,
          'geo-cache.json',
          utf8.encode(jsonEncode(geoMetadata)),
        );
      }
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
    VpnProgressCallback progress,
  ) async {
    final pending = <Future<void> Function()>[];
    var completed = 0;
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
          progress(
            VpnImportProgress(
              VpnImportStep.providers,
              completed: ++completed,
              total: pending.length,
            ),
          );
        });
      }
    }
    var index = 0;
    var failed = false;
    if (pending.isNotEmpty) {
      progress(
        VpnImportProgress(VpnImportStep.providers, total: pending.length),
      );
    }
    await Future.wait(
      List.generate(pending.length.clamp(0, 4), (_) async {
        while (!failed && index < pending.length) {
          try {
            await pending[index++]();
          } catch (_) {
            failed = true;
            rethrow;
          }
        }
      }),
    );
  }

  static Map<String, Object> _geoMetadata(String url, DateTime fetchedAt) => {
    'source': sha256.convert(utf8.encode(url)).toString(),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  Future<(List<int>, DateTime)?> _cachedGeodata(
    Profile? committed,
    String name,
    String url,
    Object? interval,
    bool localOnly,
  ) async {
    final generation = committed?.snapshot.generation;
    if (generation == null) return null;
    try {
      final metadata = await store.readVerifiedResource(
        generation,
        'geo-cache.json',
      );
      if (metadata == null) {
        if (!localOnly) return null;
        final effective = await store.readVerifiedResource(
          generation,
          'effective.yaml',
        );
        if (effective == null) return null;
        final raw = loadYaml(utf8.decode(effective));
        if (raw is! Map) return null;
        final configured = raw['geox-url'];
        final resource = geoResources[name]!;
        final previousUrl = _httpUrl(
          (configured is Map ? configured[resource.$2] : null) ??
              defaultGeoXUrl[resource.$1],
        );
        if (previousUrl != url) return null;
        final bytes = await store.readVerifiedResource(generation, 'geo/$name');
        return bytes == null
            ? null
            : (bytes, DateTime.fromMillisecondsSinceEpoch(0));
      }
      final entry = (jsonDecode(utf8.decode(metadata)) as Map)[name];
      if (entry is! Map ||
          entry['source'] != sha256.convert(utf8.encode(url)).toString()) {
        return null;
      }
      final fetchedAt = DateTime.parse(entry['fetchedAt'] as String);
      final age = clock().difference(fetchedAt);
      final lifetime = Duration(
        hours: interval is int && interval > 0 ? interval : 24,
      );
      if (!localOnly &&
          (fetchedAt.millisecondsSinceEpoch <= 0 ||
              age.isNegative ||
              age >= lifetime)) {
        return null;
      }
      final bytes = await store.readVerifiedResource(generation, 'geo/$name');
      return bytes == null ? null : (bytes, fetchedAt);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
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
