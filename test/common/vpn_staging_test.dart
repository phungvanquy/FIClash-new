import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory home;
  late ProfileGenerationStore store;
  late List<PrepareConfigParams> calls;
  late List<PreparedConfigRef> discarded;
  const profile = Profile(
    id: 7,
    url: 'https://example.test/sub?token=a%2Bb',
    autoUpdateDuration: Duration(hours: 1),
  );
  const server = VpnServer(
    id: 'inline/QWxwaGE',
    name: 'Alpha',
    target: 'Alpha',
    type: 'Socks5',
  );
  const source =
      'proxies: [{name: Alpha, type: socks5, server: 127.0.0.1, port: 1080}]';

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-staging-test-');
    store = ProfileGenerationStore(home);
    calls = [];
    discarded = [];
  });
  tearDown(() async => home.delete(recursive: true));

  Future<PreparedConfigResult> prepare(PrepareConfigParams params) async {
    calls.add(params);
    expect(
      await store
          .resource(
            params.generation,
            params.probe == true ? 'candidate.yaml' : 'effective.yaml',
          )
          .exists(),
      isTrue,
    );
    return PreparedConfigResult(
      handle: 'handle-${calls.length}',
      generation: params.generation,
      revision: params.revision,
      servers: [server],
    );
  }

  VpnCandidateStager stager({
    VpnResourceFetch? fetch,
    Future<PreparedConfigResult> Function(PrepareConfigParams)? load,
  }) => VpnCandidateStager(
    store: store,
    fetch:
        fetch ??
        (_, _, _) async => throw StateError('Unexpected network request'),
    prepare: load ?? prepare,
    discard: (handle) async {
      discarded.add(handle);
      return true;
    },
  );

  Future<VpnPreparedCandidate> stage(
    VpnCandidateStager value, {
    String text = source,
    void Function()? check,
  }) => value.stage(
    profile: profile,
    source: utf8.encode(text),
    revision: 1,
    testUrl: 'https://example.test/check',
    cancel: CancelToken(),
    checkCurrent: check ?? () {},
    overrides: (raw) async => raw,
  );

  test(
    'seals original bytes, effective config and catalog only after both preparations',
    () async {
      final candidate = await stage(stager());
      final generation = candidate.profile.snapshot.generation!;
      expect(await store.load(generation), candidate.profile);
      expect(
        await store.resource(generation, 'source.yaml').readAsString(),
        source,
      );
      expect(calls.map((call) => call.probe), [true, null]);
      expect(discarded, [
        const PreparedConfigRef(handle: 'handle-1', revision: 1),
      ]);
      expect(candidate.prepared.handle, 'handle-2');
      expect(candidate.profile.snapshot.managedGroups, isNotNull);
      expect(await File('${home.path}/config.yaml').exists(), isFalse);
      expect(await store.pending(), isNull);
    },
  );

  test(
    'offline preparation copies HTTP providers without network access',
    () async {
      var loads = 0;
      final staged = await stager().stage(
        profile: profile,
        source: utf8.encode(
          '$source\nproxy-providers: {remote: {type: http, url: https://example.test/provider}}',
        ),
        revision: 1,
        testUrl: 'https://example.test/check',
        cancel: CancelToken(),
        checkCurrent: () {},
        overrides: (raw) async => raw,
        localOnly: true,
        localResource: (section, name, definition) async {
          loads++;
          expect(section, 'proxy-providers');
          expect(name, 'remote');
          return utf8.encode('proxies: []');
        },
      );
      expect(loads, 1);
      final resources = VpnProfileResources(store);
      expect(
        utf8.decode(
          await resources.provider(
            staged.profile,
            'proxy-providers',
            'remote',
            {},
          ),
        ),
        'proxies: []',
      );
    },
  );

  test(
    'refresh fetches only due resources and retains other refresh timestamps',
    () async {
      final originalDate = DateTime.utc(2020);
      final previous = profile.copyWith.snapshot(
        providerRefresh: [
          VpnProviderRefresh(
            section: 'proxy-providers',
            name: 'a',
            interval: 60,
            lastUpdate: originalDate,
          ),
          VpnProviderRefresh(
            section: 'rule-providers',
            name: 'b',
            interval: 300,
            lastUpdate: originalDate,
          ),
        ],
      );
      final fetched = <String>[];
      final cached = <String>[];
      final candidate =
          await stager(
            fetch: (url, headers, cancel) async {
              fetched.add(url);
              return VpnDownload(utf8.encode('proxies: []'));
            },
          ).stage(
            profile: previous,
            source: utf8.encode(
              '$source\n'
              'proxy-providers: {a: {type: http, url: https://example.test/a, interval: 60}}\n'
              'rule-providers: {b: {type: http, url: https://example.test/b, interval: 300, behavior: domain}}',
            ),
            revision: 2,
            testUrl: 'https://example.test/check',
            cancel: CancelToken(),
            checkCurrent: () {},
            overrides: (raw) async => raw,
            refreshResources: {'proxy-providers/a'},
            recordFetchTime: false,
            localResource: (section, name, definition) async {
              cached.add('$section/$name');
              return utf8.encode('payload: [example.test]');
            },
          );
      expect(fetched, ['https://example.test/a']);
      expect(cached, ['rule-providers/b']);
      expect(
        candidate.profile.snapshot.providerRefresh.first.lastUpdate!.isAfter(
          originalDate,
        ),
        isTrue,
      );
      expect(
        candidate.profile.snapshot.providerRefresh.last.lastUpdate,
        originalDate,
      );
      expect(candidate.profile.lastUpdateDate, previous.lastUpdateDate);
      expect(
        await store.load(candidate.profile.snapshot.generation!),
        candidate.profile,
      );
    },
  );

  test('missing offline geodata never initiates a remote download', () async {
    final value = stager(
      load: (_) async => throw const CoreMethodException(
        code: 'resource_required',
        message: 'missing',
        details: {'resource': 'GeoSite.dat'},
      ),
    );
    await expectLater(
      value.stage(
        profile: profile,
        source: utf8.encode(source),
        revision: 1,
        testUrl: 'https://example.test/check',
        cancel: CancelToken(),
        checkCurrent: () {},
        overrides: (raw) async => raw,
        localOnly: true,
      ),
      throwsA(isA<VpnLocalResourceUnavailable>()),
    );
    expect(await store.generations.list().toList(), isEmpty);
  });

  test(
    'fetches provider bytes with their own headers into confined distinct paths',
    () async {
      final requests = <(String, Map<String, List<String>>)>[];
      final candidate = await stage(
        stager(
          fetch: (url, headers, cancel) async {
            requests.add((url, headers));
            return VpnDownload(utf8.encode('proxies: []'));
          },
        ),
        text:
            '''
$source
proxy-providers:
  First: {type: http, url: 'https://example.test/provider?token=a%2Bb', path: '/must/not/write', header: {Authorization: [first]}}
  Second: {type: http, url: 'https://example.test/provider?token=a%2Bb', path: '/must/not/write', header: {Authorization: [second]}}
''',
      );
      expect(requests.map((request) => request.$1).toSet(), {
        'https://example.test/provider?token=a%2Bb',
      });
      expect(
        requests.map((request) => request.$2['Authorization']!.single).toSet(),
        {'first', 'second'},
      );
      final generation = candidate.profile.snapshot.generation!;
      final raw =
          loadYaml(
                await store
                    .resource(generation, 'effective.yaml')
                    .readAsString(),
              )
              as Map;
      final providers = raw['proxy-providers'] as Map;
      final first = providers['First']['path'] as String;
      final second = providers['Second']['path'] as String;
      expect(first, startsWith(store.directory(generation).path));
      expect(first, isNot(second));
      expect(await File(first).readAsString(), 'proxies: []');
    },
  );

  test(
    'failed provider fetch leaves old files untouched and releases staging',
    () async {
      final old = File('${home.path}/config.yaml');
      await old.writeAsString('old bytes');
      await expectLater(
        stage(
          stager(
            fetch: (_, _, _) async => throw const HttpException('offline'),
          ),
          text:
              '$source\nproxy-providers: {Remote: {type: http, url: "https://example.test/provider"}}',
        ),
        throwsA(isA<HttpException>()),
      );
      expect(await old.readAsString(), 'old bytes');
      expect(await store.generations.list().toList(), isEmpty);
      expect(calls, isEmpty);
    },
  );

  test('late preparation failure discards only candidate resources', () async {
    await expectLater(
      stage(
        stager(
          load: (params) async {
            if (params.probe != true) {
              throw const CoreMethodException(
                code: 'prepare_failed',
                message: 'invalid rule',
              );
            }
            return prepare(params);
          },
        ),
      ),
      throwsA(isA<CoreMethodException>()),
    );
    expect(discarded, hasLength(1));
    expect(await store.generations.list().toList(), isEmpty);
  });

  test(
    'cancellation after final preparation releases its handle and generation',
    () async {
      var cancelled = false;
      final value = stager(
        load: (params) async {
          final result = await prepare(params);
          if (params.probe != true) cancelled = true;
          return result;
        },
      );
      await expectLater(
        stage(
          value,
          check: () {
            if (cancelled) throw const FormatException('cancelled');
          },
        ),
        throwsFormatException,
      );
      expect(discarded.map((handle) => handle.handle), [
        'handle-1',
        'handle-2',
      ]);
      expect(await store.generations.list().toList(), isEmpty);
    },
  );

  test('fetches only geodata requested by detached parsing', () async {
    final fetched = <String>[];
    final value = stager(
      fetch: (url, _, _) async {
        fetched.add(url);
        return VpnDownload(utf8.encode('private geodata'));
      },
      load: (params) async {
        if (!await store
            .resource(params.generation, 'geo/GeoSite.dat')
            .exists()) {
          throw const CoreMethodException(
            code: 'resource_required',
            message: 'required',
            details: {'resource': 'GeoSite.dat'},
          );
        }
        return prepare(params);
      },
    );
    final candidate = await stage(
      value,
      text:
          '$source\ngeox-url: {geosite: "https://example.test/geosite?token=a%2Bb"}',
    );
    expect(fetched, ['https://example.test/geosite?token=a%2Bb']);
    expect(
      await store
          .resource(candidate.profile.snapshot.generation!, 'geo/GeoSite.dat')
          .readAsString(),
      'private geodata',
    );
    expect(await File('${home.path}/GeoSite.dat').exists(), isFalse);
  });

  test('does not read arbitrary source-provided local paths', () async {
    await expectLater(
      stage(
        stager(),
        text:
            '$source\nproxy-providers: {Remote: {type: file, path: /etc/passwd}}',
      ),
      throwsFormatException,
    );
    expect(await store.generations.list().toList(), isEmpty);
  });

  test('waits for concurrent downloads before failure cleanup', () async {
    final pending = Completer<VpnDownload>();
    final started = Completer<void>();
    final future = stage(
      stager(
        fetch: (url, _, _) {
          if (url.endsWith('/slow')) {
            started.complete();
            return pending.future;
          }
          return Future.error(const HttpException('failed'));
        },
      ),
      text:
          '$source\nproxy-providers: {Fast: {type: http, url: "https://example.test/fail"}, Slow: {type: http, url: "https://example.test/slow"}}',
    );
    final failure = expectLater(future, throwsA(isA<HttpException>()));
    await started.future;
    pending.complete(VpnDownload(utf8.encode('proxies: []')));
    await failure;
    expect(await store.generations.list().toList(), isEmpty);
  });
}
