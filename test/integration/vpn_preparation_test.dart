import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final executable = Platform.environment['FLCLASH_PREPARATION_TEST_CORE'];
  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: 'Tunnio',
      packageName: 'com.follow.clash',
      version: '0.0.0',
      buildNumber: '0',
    );
  });
  for (final overrideDns in [true, false]) {
    test(
      'real Core prepares import, update and replacement with geodata offline (override DNS: $overrideDns)',
      () async {
        final temporary = await Directory.systemTemp.createTemp('app-import-');
        addTearDown(() => temporary.delete(recursive: true));
        final home = await Directory(
          p.join(temporary.path, 'Test User 日本語', 'com.follow', 'clash'),
        ).create(recursive: true);
        AppPath.supportDirectory = () async => home;
        AppPath.temporaryDirectory = () async => temporary;
        AppPath.cacheDirectory = () async => home;
        await appPath.dataDir.future;
        await appPath.tempDir.future;
        await appPath.cacheDir.future;
        appPath.dataDir = Completer<Directory>()..complete(home);
        appPath.tempDir = Completer<Directory>()..complete(temporary);
        appPath.cacheDir = Completer<Directory>()..complete(home);
        SharedPreferences.setMockInitialValues({});
        final database = db.Database(NativeDatabase.memory());
        db.database = database;
        addTearDown(database.close);
        final container = ProviderContainer(
          overrides: [overrideDnsProvider.overrideWithValue(overrideDns)],
        );
        addTearDown(container.dispose);
        final action = container.read(vpnActionProvider.notifier);
        final store = ProfileGenerationStore(home);
        const profile = Profile(
          id: 1,
          url: 'https://example.test/sub',
          autoUpdateDuration: Duration(hours: 1),
        );
        const proxy =
            'proxies: [{name: Test, type: socks5, server: 127.0.0.1, port: 1080}]';
        final unavailableGeodata = <GeoResource>[];
        final stager = VpnCandidateStager(
          store: store,
          fetch: (url, _, _) async {
            for (final entry in defaultGeoXUrl.entries) {
              if (entry.value == url) {
                unavailableGeodata.add(entry.key);
                throw DioException(
                  requestOptions: RequestOptions(path: url),
                  type: DioExceptionType.unknown,
                  error: const SocketException('Geodata host is unavailable'),
                );
              }
            }
            return VpnDownload(
              url.endsWith('/proxies')
                  ? utf8.encode(proxy)
                  : utf8.encode('payload: [example.test]'),
            );
          },
          prepare: (params) async {
            final request = File(p.join(home.path, 'request.json'));
            await request.writeAsString(
              jsonEncode({'home': home.path, 'params': params.toJson()}),
            );
            final process = await Process.run(
              executable!,
              ['-test.run=^TestAppCandidatePreparation\$', '-test.timeout=30s'],
              environment: {'FLCLASH_PREPARATION_REQUEST': request.path},
            );
            expect(
              process.exitCode,
              0,
              reason: '${process.stdout}\n${process.stderr}',
            );
            final response =
                jsonDecode(
                      await File(
                        p.join(home.path, 'response.json'),
                      ).readAsString(),
                    )
                    as Map<String, dynamic>;
            final error = response['error'] as Map<String, dynamic>?;
            if (error != null) {
              throw CoreMethodException(
                code: error['code'] as String,
                message: error['message'] as String,
                details: error['details'],
              );
            }
            return PreparedConfigResult.fromJson(
              response['result'] as Map<String, dynamic>,
            );
          },
          discard: (_) async => true,
        );
        Profile? committed;
        for (final (replacing, source) in [
          (false, proxy),
          (
            false,
            '''
proxy-providers:
  Remote:
    type: http
    url: https://example.test/proxies
    interval: 3600
rule-providers:
  Domains:
    type: http
    behavior: domain
    url: https://example.test/rules
proxy-groups: [{name: Select, type: select, use: [Remote]}]
rules: ["RULE-SET,Domains,Select", "MATCH,Select"]
''',
          ),
          (true, '$proxy\nrules: ["GEOIP,CN,DIRECT", "MATCH,Test"]'),
        ]) {
          if (replacing && !overrideDns) {
            expect(
              await store
                  .resource(committed!.snapshot.generation!, 'geo/Country.mmdb')
                  .exists(),
              isFalse,
            );
          }
          final incoming = replacing
              ? profile.copyWith(id: 2)
              : committed ?? profile;
          final candidate = await stager.stage(
            profile: incoming,
            source: utf8.encode(
              '$source\ndns: {enable: true, nameserver: [1.1.1.1]}',
            ),
            revision: (committed?.snapshot.revision ?? 0) + 1,
            testUrl: 'https://example.test/check',
            cancel: CancelToken(),
            checkCurrent: () {},
            committed: committed,
            overrides: (raw) => action.prepareOverrides(incoming, raw),
          );
          expect(candidate.profile.snapshot.servers.single.name, 'Test');
          expect(
            await store.load(candidate.profile.snapshot.generation!),
            candidate.profile,
          );
          committed = candidate.profile;
        }
        expect(unavailableGeodata, contains(GeoResource.MMDB));
        expect(committed!.id, 2);
      },
      skip: executable == null
          ? 'set FLCLASH_PREPARATION_TEST_CORE to the Go test binary'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
