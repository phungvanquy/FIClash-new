import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

void main() {
  late Directory home;
  late Database database;
  late ProfileGenerationStore store;
  late VpnArchiveStore archives;
  late VpnImportCoordinator importer;
  late VpnMigrationCoordinator migration;
  late List<Profile> profiles;
  late Future<void> Function(String) snapshot;
  Profile? active;
  var activations = 0;
  var failActivation = false;
  Object? preparationFailure;
  const source =
      'proxies: [{name: A, type: socks5, server: 127.0.0.1, port: 1080}]';

  Future<void> writeSource(int id, String body) async {
    final file = File(p.join(home.path, 'profiles', '$id.yaml'));
    await file.parent.create(recursive: true);
    await file.writeAsString(body);
  }

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-migration-test-');
    database = Database(NativeDatabase.memory());
    store = ProfileGenerationStore(home);
    archives = VpnArchiveStore(home);
    profiles = [
      for (final id in [1, 2])
        Profile(
          id: id,
          label: 'Legacy $id',
          url: 'https://example.test/$id',
          order: id - 1,
          selectedMap: const {'Original': 'A'},
          lastUpdateDate: DateTime.utc(2025),
          autoUpdateDuration: const Duration(hours: 1),
        ),
    ];
    await database.profilesDao.setAll(profiles);
    profiles = await database.profilesDao.query().get();
    for (final profile in profiles) {
      await writeSource(profile.id, source);
    }
    active = profiles.last;
    activations = 0;
    failActivation = false;
    preparationFailure = null;
    await store.restoreRuntimeBytes(utf8.encode(source));
    var handle = 0;
    importer = VpnImportCoordinator(
      repository: database.singleProfile,
      store: store,
      stager: VpnCandidateStager(
        store: store,
        fetch: (_, _, _) async =>
            throw StateError('Migration must stay offline'),
        prepare: (params) async {
          final failure = preparationFailure;
          if (failure != null) {
            Error.throwWithStackTrace(failure, StackTrace.current);
          }
          final path = params.probe == true
              ? 'candidate.yaml'
              : 'effective.yaml';
          final config =
              loadYaml(
                    await store
                        .resource(params.generation, path)
                        .readAsString(),
                  )
                  as YamlMap;
          if ((config['proxies'] as List?)?.isEmpty != false) {
            throw const FormatException('Empty inventory');
          }
          return PreparedConfigResult(
            handle: 'handle-${++handle}',
            generation: params.generation,
            revision: params.revision,
            servers: const [
              VpnServer(
                id: 'inline/QQ',
                name: 'A',
                target: 'A',
                type: 'Socks5',
              ),
            ],
          );
        },
        discard: (_) async => true,
      ),
      serialize: SerialTaskScheduler().run,
      activate: (candidate) async {
        activations++;
        active = candidate.profile;
        if (failActivation) throw StateError('activation failed');
      },
      restore: (profile) async => active = profile,
      publish: (_) async {},
      overrides: (_, raw, {ownedData}) async => raw,
      testUrl: () => 'https://example.test/check',
      maintenanceFailure: (_, _) {},
    );
    snapshot = (path) => database.customStatement('VACUUM INTO ?', [path]);
    migration = VpnMigrationCoordinator(
      repository: database.singleProfile,
      store: store,
      archives: archives,
      importer: importer,
      snapshotDatabase: (path) => snapshot(path),
      settings: () => {'version': 1, 'currentProfileId': 2},
    );
  });

  tearDown(() async {
    importer.dispose();
    await database.close();
    await home.delete(recursive: true);
  });

  test(
    'offline migration retains selected profile, timestamp and manual selection',
    () async {
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isTrue);
      expect(result.profile?.id, 2);
      expect(result.profile?.lastUpdateDate?.toUtc(), DateTime.utc(2025));
      expect(
        result.profile?.snapshot.selection,
        const VpnSelection.server('inline/QQ'),
      );
      expect(activations, 1);
      expect(active, result.profile);
      expect(await database.profilesDao.query().get(), [result.profile]);
      final files = await archives.verify(File(result.archive!));
      expect(
        files.keys,
        containsAll(['profiles/1.yaml', 'profiles/2.yaml', 'database.sqlite']),
      );
      final second = await migration.run(selectedId: 1);
      expect(second.profile, result.profile);
      expect(second.archive, result.archive);
      expect(activations, 1);
      expect(await archives.recovery.list().toList(), hasLength(1));
    },
  );

  test(
    'missing selected content falls back to first usable ordered profile',
    () async {
      await File(p.join(home.path, 'profiles', '2.yaml')).delete();
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isTrue);
      expect(result.profile?.id, 1);
      expect(await archives.verify(File(result.archive!)), isNotEmpty);
    },
  );

  test('unknown selected id falls back to existing order', () async {
    final result = await migration.run(selectedId: 999);
    expect(result.complete, isTrue);
    expect(result.profile?.id, 1);
  });

  test(
    'offline upgrade copies the legacy HTTP provider cache without renaming it',
    () async {
      const url = 'https://example.test/provider?token=private';
      final cache = File(
        p.join(home.path, 'profiles', 'providers', '2', 'proxies', url.toMd5()),
      );
      await cache.parent.create(recursive: true);
      await cache.writeAsString('proxies: []');
      await writeSource(
        2,
        '$source\nproxy-providers: {remote: {type: http, url: "$url"}}',
      );
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isTrue);
      expect(await cache.readAsString(), 'proxies: []');
      expect(
        utf8.decode(
          await VpnProfileResources(
            store,
          ).provider(result.profile!, 'proxy-providers', 'remote', {}),
        ),
        'proxies: []',
      );
    },
  );

  for (final failure in [
    const FileSystemException('staging disk failure'),
    const CoreMethodException(
      code: 'core_unavailable',
      message: 'not initialized',
    ),
  ]) {
    test(
      'environment failure ${failure.runtimeType} does not classify legacy profiles as unusable',
      () async {
        preparationFailure = failure;
        final result = await migration.run(selectedId: 2);
        expect(result.complete, isFalse);
        expect(await database.profilesDao.query().get(), profiles);
        expect((await database.singleProfile.state()).migrationVersion, 0);
        expect(activations, 0);
      },
    );
  }

  test(
    'no usable profiles enters empty state only after preserving an archive',
    () async {
      for (final profile in profiles) {
        await writeSource(profile.id, 'proxies: []');
      }
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isTrue);
      expect(result.profile, isNull);
      expect(activations, 0);
      expect(await database.profilesDao.query().get(), isEmpty);
      expect((await database.singleProfile.state()).migrationVersion, 1);
      final zip = ZipDecoder().decodeBytes(
        await File(result.archive!).readAsBytes(),
      );
      expect(zip.findFile('profiles/1.yaml'), isNotNull);
      expect(zip.findFile('profiles/2.yaml'), isNotNull);
      expect((await migration.run()).archive, result.archive);
    },
  );

  test(
    'archive failure leaves legacy rows, files and runtime untouched',
    () async {
      snapshot = (_) async => throw const FileSystemException('archive failed');
      final before = await store.runtimeBytes();
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isFalse);
      expect(result.error, isA<FileSystemException>());
      expect(await database.profilesDao.query().get(), profiles);
      expect(await store.runtimeBytes(), before);
      expect(activations, 0);
      expect((await database.singleProfile.state()).migrationVersion, 0);
    },
  );

  test(
    'activation failure restores the selected legacy profile without trying another',
    () async {
      failActivation = true;
      final result = await migration.run(selectedId: 2);
      expect(result.complete, isFalse);
      expect(await database.profilesDao.query().get(), profiles);
      expect(active, profiles.last);
      expect(activations, 1);
      expect(await store.pending(), isNull);
      expect(await archives.verify(File(result.archive!)), isNotEmpty);
    },
  );

  test(
    'a newer failed explicit import still cancels in-flight migration',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final original = snapshot;
      snapshot = (path) async {
        entered.complete();
        await release.future;
        await original(path);
      };
      final pending = migration.run(selectedId: 2);
      await entered.future;
      final explicit = await importer.submit(
        VpnImportRequest(profile: profiles.first.copyWith(url: 'invalid')),
      );
      expect(explicit.outcome, VpnImportOutcome.failed);
      release.complete();
      final result = await pending;
      expect(result.complete, isFalse);
      expect(result.error, isA<VpnImportCancelled>());
      expect(await database.profilesDao.query().get(), profiles);
      expect(activations, 0);
    },
  );
}
