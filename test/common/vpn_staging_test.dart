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
  late DateTime now;
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
    now = DateTime.utc(2026, 9, 22);
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
    Future<List<int>> Function(String)? bundledGeodata,
  }) => VpnCandidateStager(
    store: store,
    fetch:
        fetch ??
        (_, _, _) async => throw StateError('Unexpected network request'),
    prepare: load ?? prepare,
    clock: () => now,
    bundledGeodata:
        bundledGeodata ??
        (_) async => throw StateError('Unexpected bundled resource'),
    discard: (handle) async {
      discarded.add(handle);
      return true;
    },
  );

  Future<VpnPreparedCandidate> stage(
    VpnCandidateStager value, {
    String text = source,
    void Function()? check,
    Profile? previous,
    bool localOnly = false,
    Map<String, List<int>> resources = const {},
    VpnProgressCallback? onProgress,
  }) => value.stage(
    profile: profile,
    source: utf8.encode(text),
    revision: (previous?.snapshot.revision ?? 0) + 1,
    testUrl: 'https://example.test/check',
    cancel: CancelToken(),
    checkCurrent: check ?? () {},
    overrides: (raw) async => raw,
    committed: previous,
    localOnly: localOnly,
    resources: resources,
    onProgress: onProgress,
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

  test(
    'first import stages default geodata without a second download',
    () async {
      final loaded = <String>[];
      final requested = VpnCandidateStager.geoResources.keys.toList();
      final value = stager(
        bundledGeodata: (name) async {
          loaded.add(name);
          return utf8.encode('bundled $name');
        },
        load: (params) async {
          for (final name in requested) {
            if (!await store
                .resource(params.generation, 'geo/$name')
                .exists()) {
              throw CoreMethodException(
                code: 'resource_required',
                message: 'required',
                details: {'resource': name},
              );
            }
          }
          return prepare(params);
        },
      );
      final candidate = await stage(value);
      final generation = candidate.profile.snapshot.generation!;
      expect(loaded, requested);
      for (final name in requested) {
        expect(
          await store.resource(generation, 'geo/$name').readAsString(),
          'bundled $name',
        );
      }
      final metadata =
          jsonDecode(
                await store
                    .resource(generation, 'geo-cache.json')
                    .readAsString(),
              )
              as Map;
      expect(
        metadata.values.map((entry) => entry['fetchedAt']),
        everyElement(
          DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
        ),
      );
      await store.load(generation);
    },
  );

  test(
    'failed default geodata refresh reuses the verified bundled snapshot',
    () async {
      var bundledLoads = 0;
      var fetches = 0;
      final value = stager(
        bundledGeodata: (name) async {
          bundledLoads++;
          return utf8.encode('bundled $name');
        },
        fetch: (url, _, _) async {
          fetches++;
          throw DioException(
            requestOptions: RequestOptions(path: url),
            type: DioExceptionType.unknown,
          );
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
      final first = await stage(value);
      final second = await stage(value, previous: first.profile);
      expect(bundledLoads, 1);
      expect(fetches, 1);
      expect(
        await store
            .resource(second.profile.snapshot.generation!, 'geo/GeoSite.dat')
            .readAsString(),
        'bundled GeoSite.dat',
      );
      final metadata =
          jsonDecode(
                await store
                    .resource(
                      second.profile.snapshot.generation!,
                      'geo-cache.json',
                    )
                    .readAsString(),
              )
              as Map;
      expect(
        metadata['GeoSite.dat']['fetchedAt'],
        DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
      );
    },
  );

  group('replacement geodata fallback', () {
    Future<PreparedConfigResult> requireResource(
      PrepareConfigParams params,
      String name,
    ) async {
      if (!await store.resource(params.generation, 'geo/$name').exists()) {
        throw CoreMethodException(
          code: 'resource_required',
          message: 'required',
          details: {'resource': name},
        );
      }
      return prepare(params);
    }

    for (final name in VpnCandidateStager.geoResources.keys) {
      test(
        'uses bundled $name when it is missing from the old snapshot',
        () async {
          final old = await stage(stager());
          final loaded = <String>[];
          var fetches = 0;
          final replacement = await stage(
            stager(
              fetch: (url, _, _) async {
                fetches++;
                throw DioException(requestOptions: RequestOptions(path: url));
              },
              bundledGeodata: (resource) async {
                loaded.add(resource);
                return utf8.encode('bundled $resource');
              },
              load: (params) => requireResource(params, name),
            ),
            previous: old.profile,
          );
          expect(fetches, 1);
          expect(loaded, [name]);
          final generation = replacement.profile.snapshot.generation!;
          expect(
            await store.resource(generation, 'geo/$name').readAsString(),
            'bundled $name',
          );
          final metadata =
              jsonDecode(
                    await store
                        .resource(generation, 'geo-cache.json')
                        .readAsString(),
                  )
                  as Map;
          expect(
            metadata[name]['fetchedAt'],
            DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
          );
          expect(await store.load(generation), replacement.profile);
          expect(
            await store.load(old.profile.snapshot.generation!),
            old.profile,
          );
        },
      );
    }

    test('can replace a legacy profile without a snapshot cache', () async {
      final candidate = await stage(
        stager(
          fetch: (_, _, _) async => throw const SocketException('offline'),
          bundledGeodata: (_) async => utf8.encode('bundled database'),
          load: (params) => requireResource(params, 'Country.mmdb'),
        ),
        previous: profile,
      );
      expect(
        await store.load(candidate.profile.snapshot.generation!),
        candidate.profile,
      );
    });

    for (final failedFile in ['geo-cache.json', 'geo/GeoSite.dat']) {
      test('uses the bundle instead of corrupt $failedFile', () async {
        final value = stager(
          fetch: (_, _, _) async => throw const HttpException('offline'),
          bundledGeodata: (_) async => utf8.encode('bundled database'),
          load: (params) => requireResource(params, 'GeoSite.dat'),
        );
        final old = await stage(value);
        final corrupt = store.resource(
          old.profile.snapshot.generation!,
          failedFile,
        );
        await corrupt.writeAsString('corrupt');
        final replacement = await stage(value, previous: old.profile);
        expect(
          await store
              .resource(
                replacement.profile.snapshot.generation!,
                'geo/GeoSite.dat',
              )
              .readAsString(),
          'bundled database',
        );
        expect(await corrupt.readAsString(), 'corrupt');
      });
    }

    for (final error in <Exception>[
      DioException(
        requestOptions: RequestOptions(path: 'https://example.test/geodata'),
        type: DioExceptionType.cancel,
      ),
      const FormatException('Unexpected failure'),
    ]) {
      test('does not substitute bundled data for $error', () async {
        final old = await stage(stager());
        await expectLater(
          stage(
            stager(
              fetch: (_, _, _) async => throw error,
              load: (params) => requireResource(params, 'GeoSite.dat'),
            ),
            previous: old.profile,
          ),
          throwsA(same(error)),
        );
        expect(await store.generations.list().toList(), hasLength(1));
      });
    }
  });

  test('bundled geodata is never substituted for a custom source', () async {
    final value = stager(
      fetch: (_, _, _) async =>
          throw const HttpException('Custom source is unavailable'),
      bundledGeodata: (_) async => fail('Custom source must be respected'),
      load: (_) async => throw const CoreMethodException(
        code: 'resource_required',
        message: 'required',
        details: {'resource': 'GeoSite.dat'},
      ),
    );
    await expectLater(
      stage(
        value,
        text: '$source\ngeox-url: {geosite: "https://example.test/custom"}',
      ),
      throwsA(isA<HttpException>()),
    );
    expect(await store.generations.list().toList(), isEmpty);
    expect(await File('${home.path}/config.yaml').exists(), isFalse);
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

  group('geodata snapshot cache', () {
    const text =
        '$source\ngeox-url: {geosite: "https://example.test/geo?token=secret"}';
    late List<String> fetched;
    late VpnCandidateStager value;

    setUp(() {
      fetched = [];
      value = stager(
        fetch: (url, _, _) async {
          fetched.add(url);
          return VpnDownload(utf8.encode('database-${fetched.length}'));
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
    });

    Future<String> database(VpnPreparedCandidate candidate) => store
        .resource(candidate.profile.snapshot.generation!, 'geo/GeoSite.dat')
        .readAsString();

    test(
      'reuses fresh verified bytes without extending their freshness',
      () async {
        final first = await stage(value, text: text);
        now = now.add(const Duration(hours: 23));
        final second = await stage(value, text: text, previous: first.profile);
        expect(fetched, hasLength(1));
        expect(await database(second), 'database-1');
        expect(
          await store.load(second.profile.snapshot.generation!),
          second.profile,
        );
        final metadata = await store
            .resource(second.profile.snapshot.generation!, 'geo-cache.json')
            .readAsString();
        expect(metadata, isNot(contains('secret')));
        now = now.add(const Duration(hours: 2));
        final third = await stage(value, text: text, previous: second.profile);
        expect(fetched, hasLength(2));
        expect(await database(third), 'database-2');
        expect(await database(first), 'database-1');
      },
    );

    test(
      'changed resource source cannot reuse an unrelated database',
      () async {
        final first = await stage(value, text: text);
        final second = await stage(
          value,
          text: text.replaceAll('secret', 'other'),
          previous: first.profile,
        );
        expect(fetched, hasLength(2));
        expect(await database(second), 'database-2');
      },
    );

    test('failed refresh cannot reuse data from a different source', () async {
      final first = await stage(value, text: text);
      final failing = stager(
        fetch: (url, _, _) async => throw DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.unknown,
        ),
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
      await expectLater(
        stage(
          failing,
          text: text.replaceAll('secret', 'other'),
          previous: first.profile,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test(
      'corrupt cached resource is fetched again without editing the old snapshot',
      () async {
        final first = await stage(value, text: text);
        final old = store.resource(
          first.profile.snapshot.generation!,
          'geo/GeoSite.dat',
        );
        await old.writeAsString('corrupt');
        final second = await stage(value, text: text, previous: first.profile);
        expect(fetched, hasLength(2));
        expect(await database(second), 'database-2');
        expect(await old.readAsString(), 'corrupt');
      },
    );

    test(
      'offline edits may reuse expired data but never a changed source',
      () async {
        final first = await stage(value, text: text);
        now = now.add(const Duration(days: 30));
        final second = await stage(
          value,
          text: text,
          previous: first.profile,
          localOnly: true,
        );
        expect(await database(second), 'database-1');
        expect(fetched, hasLength(1));
        await expectLater(
          stage(
            value,
            text: text.replaceAll('secret', 'other'),
            previous: first.profile,
            localOnly: true,
          ),
          throwsA(isA<VpnLocalResourceUnavailable>()),
        );
        expect(fetched, hasLength(1));
      },
    );

    test(
      'restored resources are available in the parser geo directory offline',
      () async {
        final first = await stage(
          value,
          text: text,
          localOnly: true,
          resources: {'GeoSite.dat': utf8.encode('restored')},
        );
        expect(fetched, isEmpty);
        expect(await database(first), 'restored');
        final second = await stage(value, text: text, previous: first.profile);
        expect(fetched, hasLength(1));
        expect(await database(second), 'database-1');
      },
    );

    test('respects a shorter configured refresh interval', () async {
      final first = await stage(value, text: text);
      now = now.add(const Duration(hours: 2));
      await stage(
        value,
        text: '$text\ngeo-update-interval: 1',
        previous: first.profile,
      );
      expect(fetched, hasLength(2));
    });

    test(
      'older unstamped generations remain usable for offline edits',
      () async {
        final generation = await store.allocate();
        final previous = profile.copyWith.snapshot(
          generation: generation,
          revision: 1,
        );
        await store.write(generation, 'source.yaml', utf8.encode(text));
        await store.write(generation, 'effective.yaml', utf8.encode(text));
        await store.write(
          generation,
          'geo/GeoSite.dat',
          utf8.encode('older database'),
        );
        await store.seal(previous);
        final edited = await stage(
          value,
          text: text,
          previous: previous,
          localOnly: true,
        );
        expect(await database(edited), 'older database');
        expect(fetched, isEmpty);
        await stage(value, text: text, previous: edited.profile);
        expect(fetched, hasLength(1));
      },
    );

    test(
      'corrupt offline cache cannot silently fall back to unrelated global data',
      () async {
        final first = await stage(value, text: text);
        await store
            .resource(first.profile.snapshot.generation!, 'geo/GeoSite.dat')
            .writeAsString('corrupt');
        await File('${home.path}/GeoSite.dat').writeAsString('unrelated');
        await expectLater(
          stage(value, text: text, previous: first.profile, localOnly: true),
          throwsA(isA<VpnLocalResourceUnavailable>()),
        );
        expect(fetched, hasLength(1));
      },
    );
  });

  test(
    'reports completed provider resources and both validation stages',
    () async {
      final progress = <VpnImportProgress>[];
      await stage(
        stager(
          fetch: (_, _, _) async => VpnDownload(utf8.encode('proxies: []')),
        ),
        text:
            '$source\nproxy-providers: {a: {type: http, url: https://example.test/a}, b: {type: http, url: https://example.test/b}}',
        onProgress: progress.add,
      );
      expect(
        progress
            .where((item) => item.step == VpnImportStep.providers)
            .map((item) => (item.completed, item.total)),
        [(0, 2), (1, 2), (2, 2)],
      );
      expect(
        progress.where((item) => item.step == VpnImportStep.validation),
        hasLength(2),
      );
      expect(progress.last.step, VpnImportStep.saving);
    },
  );

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

  test(
    'provider failure stops queued transfers but awaits the four active workers',
    () async {
      final started = Completer<void>();
      final transfers = <Completer<VpnDownload>>[];
      final operation = stage(
        stager(
          fetch: (_, _, _) {
            final transfer = Completer<VpnDownload>();
            transfers.add(transfer);
            if (transfers.length == 4) started.complete();
            return transfer.future;
          },
        ),
        text:
            '$source\nproxy-providers:\n${List.generate(6, (index) => '  p$index: {type: http, url: https://example.test/$index}').join('\n')}',
      );
      final failed = expectLater(operation, throwsA(isA<HttpException>()));
      await started.future;
      transfers.first.completeError(const HttpException('offline'));
      await Future<void>.delayed(Duration.zero);
      for (final transfer in transfers.skip(1)) {
        transfer.complete(VpnDownload(utf8.encode('proxies: []')));
      }
      await failed;
      expect(transfers, hasLength(4));
      expect(await store.generations.list().toList(), isEmpty);
    },
  );
}
