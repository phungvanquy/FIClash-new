import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Vpn extends VpnAction {
  final restoredPorts = <int>[];

  @override
  Future<Map<String, dynamic>> prepareOverrides(
    Profile profile,
    Map<String, dynamic> source, {
    db.ProfileOwnedData? ownedData,
  }) async => source;

  @override
  Future<Map<String, dynamic>> prepareRestoreSource({
    required Profile profile,
    required Map<String, dynamic> source,
    required db.ProfileOwnedData ownedData,
    required Config settings,
    required List<Rule> globalRules,
    Script? script,
    String? scriptContent,
  }) async {
    restoredPorts.add(settings.patchClashConfig.mixedPort);
    return {...source, 'mixed-port': settings.patchClashConfig.mixedPort};
  }
}

class _Archive extends BackupAction {
  _Archive(this.path);
  final String path;

  @override
  Future<String> backup() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const yaml =
      'proxies: [{name: A, type: socks5, server: 127.0.0.1, port: 1080}]';
  const profile = Profile(
    id: 10,
    label: 'Backup',
    autoUpdateDuration: Duration(hours: 1),
  );
  late Directory home;
  late Directory staging;
  late db.Database database;
  late ProfileGenerationStore store;
  late ProviderContainer container;
  late _Core core;
  late _Vpn vpn;
  late BackupAction action;
  late Map<String, PrepareConfigParams> handles;
  late List<VpnServer> catalog;
  var activations = 0;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    await preferences.isInit;
    registerFallbackValue(
      const PrepareConfigParams(generation: '', revision: 1),
    );
    registerFallbackValue(const PreparedConfigRef(handle: '', revision: 1));
    registerFallbackValue(
      const ActivateConfigParams(
        prepared: PreparedConfigRef(handle: '', revision: 1),
        setup: SetupParams(selectedMap: {}, testUrl: ''),
      ),
    );
    registerFallbackValue(const SetupParams(selectedMap: {}, testUrl: ''));
  });

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-backup-test-');
    staging = await Directory.systemTemp.createTemp('vpn-restore-test-');
    AppPath.supportDirectory = () async => home;
    AppPath.temporaryDirectory = () async => home;
    AppPath.cacheDirectory = () async => home;
    await Future.wait([
      appPath.dataDir.future,
      appPath.tempDir.future,
      appPath.cacheDir.future,
    ]);
    appPath.dataDir = Completer<Directory>()..complete(home);
    appPath.tempDir = Completer<Directory>()..complete(home);
    appPath.cacheDir = Completer<Directory>()..complete(home);
    database = db.Database(NativeDatabase.memory());
    db.database = database;
    store = ProfileGenerationStore(home);
    core = _Core();
    handles = {};
    catalog = const [
      VpnServer(id: 'inline/QQ', name: 'A', target: 'A', type: 'Socks5'),
    ];
    activations = 0;
    when(() => core.isInit).thenAnswer((_) async => true);
    when(() => core.prepareConfig(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.single as PrepareConfigParams;
      final handle = 'handle-${handles.length}';
      handles[handle] = request;
      return PreparedConfigResult(
        handle: handle,
        generation: request.generation,
        revision: request.revision,
        servers: catalog,
      );
    });
    when(() => core.activateConfig(any())).thenAnswer((invocation) async {
      activations++;
      final request =
          invocation.positionalArguments.single as ActivateConfigParams;
      final prepared = handles[request.prepared.handle]!;
      return ActivatedConfigResult(
        generation: prepared.generation,
        revision: prepared.revision,
      );
    });
    when(() => core.discardConfig(any())).thenAnswer((_) async => true);
    when(() => core.setupConfig(any())).thenAnswer((_) async => '');
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(proxies: {}, all: []));
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profileGenerationStoreProvider.overrideWith((_) async => store),
        singleProfileRepositoryProvider.overrideWithValue(
          database.singleProfile,
        ),
        vpnActionProvider.overrideWith(_Vpn.new),
        vpnResourceFetchProvider.overrideWith(
          (_) =>
              (_, _, _) async => throw StateError('Restore must stay offline'),
        ),
      ],
    );
    container.listen(configProvider, (_, _) {});
    container.listen(sharedStateProvider, (_, _) {});
    vpn = container.read(vpnActionProvider.notifier) as _Vpn;
    action = container.read(backupActionProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    await home.delete(recursive: true);
    await staging.delete(recursive: true);
  });

  Future<void> source(Profile profile, [String text = yaml]) async {
    final file = File('${staging.path}/profiles/${profile.id}.yaml');
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<Profile> current() async => (await vpn.submit(
    VpnImportRequest(
      profile: profile.copyWith(id: 1, label: 'Current'),
      bytes: utf8.encode(yaml),
    ),
  )).profile!;

  MigrationData data({
    List<Profile> profiles = const [profile],
    int? selected,
    Config? settings,
  }) => MigrationData(
    sourcePath: staging.path,
    profiles: profiles,
    configMap: {
      if (settings != null)
        ...jsonDecode(jsonEncode(settings)) as Map<String, dynamic>,
      'currentProfileId': selected,
    },
  );

  test(
    'restoring selects one profile and replaces rather than appending',
    () async {
      final previous = await current();
      final selected = profile.copyWith(id: 11, label: 'Selected');
      await source(profile);
      await source(selected);
      await action.applyRestore(
        data(profiles: [profile, selected], selected: 11),
        RestoreOption.onlyProfiles,
      );
      final rows = await database.profilesDao.query().get();
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Selected');
      expect(rows.single.id, isNot(previous.id));
      expect(rows.single.snapshot.revision, previous.snapshot.revision + 1);
      expect(activations, 2);
      expect(File('${home.path}/profiles/11.yaml').existsSync(), isFalse);
    },
  );

  test(
    'a missing or malformed selected source falls back in profile order',
    () async {
      final malformed = profile.copyWith(id: 11, label: 'Malformed', order: 1);
      final missing = profile.copyWith(id: 12, label: 'Missing', order: 0);
      await source(profile.copyWith(order: 2));
      await source(malformed, '[invalid YAML');
      await action.applyRestore(
        data(
          profiles: [missing, malformed, profile.copyWith(order: 2)],
          selected: 11,
        ),
        RestoreOption.onlyProfiles,
      );
      expect((await database.singleProfile.current())?.label, 'Backup');
      expect(activations, 1);
    },
  );

  test(
    'failed preparation preserves profile, runtime bytes, and settings',
    () async {
      final previous = await current();
      final before = container.read(configProvider);
      final runtime = await store.runtimeBytes();
      await source(profile);
      when(() => core.prepareConfig(any())).thenThrow(
        const CoreMethodException(
          code: 'prepare_failed',
          message: 'Unsupported adapter',
        ),
      );
      final restored = before.copyWith.patchClashConfig(mixedPort: 9999);
      await expectLater(
        action.applyRestore(data(settings: restored), RestoreOption.all),
        throwsA(isA<MessageException>()),
      );
      expect(await database.singleProfile.current(), previous);
      expect(container.read(configProvider), before);
      expect(await store.runtimeBytes(), runtime);
      expect(activations, 1);
      expect(vpn.restoredPorts, [9999]);
    },
  );

  test('activation failure does not publish restored settings', () async {
    final previous = await current();
    final before = container.read(configProvider);
    await source(profile);
    when(() => core.activateConfig(any())).thenThrow(
      const CoreMethodException(
        code: 'activation_failed',
        message: 'Listener failure',
      ),
    );
    await expectLater(
      action.applyRestore(
        data(settings: before.copyWith.patchClashConfig(mixedPort: 9999)),
        RestoreOption.all,
      ),
      throwsA(isA<MessageException>()),
    );
    expect(await database.singleProfile.current(), previous);
    expect(container.read(configProvider), before);
    expect((await database.singleProfile.state()).pendingRestore, isNull);
    verify(() => core.setupConfig(any())).called(1);
  });

  test(
    'all-data restore commits its settings and new script identities',
    () async {
      await current();
      final backupProfile = profile.copyWith(scriptId: 8);
      await source(backupProfile);
      final scriptFile = File('${staging.path}/scripts/8.js');
      await scriptFile.parent.create(recursive: true);
      await scriptFile.writeAsString(
        'function main(config) { return config; }',
      );
      final restored = container
          .read(configProvider)
          .copyWith
          .patchClashConfig(mixedPort: 8888);
      await action.applyRestore(
        data(profiles: [backupProfile], settings: restored).copyWith(
          scripts: [
            Script(
              id: 8,
              label: 'Restored script',
              lastUpdateTime: DateTime.utc(2026),
            ),
          ],
        ),
        RestoreOption.all,
      );
      final committed = (await database.singleProfile.current())!;
      expect(container.read(patchClashConfigProvider).mixedPort, 8888);
      expect(committed.scriptId, isNot(8));
      expect(
        File(
          '${home.path}/scripts/${committed.scriptId}.js',
        ).readAsStringSync(),
        contains('function main'),
      );
      expect(
        (await database.scriptsDao.query().get()).single.id,
        committed.scriptId,
      );
      expect((await database.singleProfile.state()).pendingRestore, isNull);
      expect((await preferences.getConfig())?.currentProfileId, committed.id);
    },
  );

  test('config-only restore leaves app settings unchanged', () async {
    await current();
    await source(profile);
    final before = container.read(patchClashConfigProvider);
    final restored = container
        .read(configProvider)
        .copyWith
        .patchClashConfig(mixedPort: 8888);
    await action.applyRestore(
      data(settings: restored),
      RestoreOption.onlyProfiles,
    );
    expect(container.read(patchClashConfigProvider), before);
    expect(vpn.restoredPorts, [before.mixedPort]);
  });

  test('database failure rolls back shared restore rows and profile', () async {
    final previous = await current();
    final before = container.read(configProvider);
    await source(profile);
    await database.customStatement(
      "CREATE TRIGGER fail_restore BEFORE UPDATE ON profile_commit_state BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(
      action.applyRestore(
        data(
          settings: before.copyWith.patchClashConfig(mixedPort: 8888),
        ).copyWith(
          rules: const [
            Rule(id: 22, ruleTarget: 'DIRECT', content: 'restore.example'),
          ],
          links: const [ProfileRuleLink(ruleId: 22, order: 'a0')],
        ),
        RestoreOption.all,
      ),
      throwsA(isA<MessageException>()),
    );
    expect(await database.singleProfile.current(), previous);
    expect(await database.rulesDao.queryGlobalAddedRules().get(), isEmpty);
    expect(container.read(configProvider), before);
  });

  test(
    'post-commit preference failure remains repairable from the database',
    () async {
      await source(profile);
      final restored = container
          .read(configProvider)
          .copyWith
          .patchClashConfig(mixedPort: 8888);
      final originalPreferences = preferences.sharedPreferencesCompleter;
      preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
        ..complete(null);
      try {
        await action.applyRestore(data(settings: restored), RestoreOption.all);
        expect(
          (await database.singleProfile.state()).pendingRestore,
          isNotNull,
        );
        expect(await store.pending(), isNotNull);
        expect(container.read(vpnFailureProvider), 'recovery_required');
      } finally {
        preferences.sharedPreferencesCompleter = originalPreferences;
      }
      container.read(patchClashConfigProvider.notifier).value =
          const PatchClashConfig();
      await vpn.recover();
      expect(container.read(patchClashConfigProvider).mixedPort, 8888);
      expect((await database.singleProfile.state()).pendingRestore, isNull);
      expect(await store.pending(), isNull);
    },
  );

  test('settings-only backup preserves an empty import state', () async {
    final restored = container
        .read(configProvider)
        .copyWith
        .patchClashConfig(mixedPort: 8888);
    await action.applyRestore(
      data(profiles: [], settings: restored),
      RestoreOption.all,
    );
    expect(await database.singleProfile.current(), isNull);
    expect(container.read(currentProfileProvider), isNull);
    expect(container.read(patchClashConfigProvider).mixedPort, 8888);
    expect(activations, 0);
  });

  test('a superseded restore cannot replace a newer import', () async {
    await source(profile);
    final intent = vpn.requestRevision;
    final latest = await current();
    await expectLater(
      action.applyRestore(data(), RestoreOption.onlyProfiles, intent: intent),
      throwsA(isA<VpnImportCancelled>()),
    );
    expect(await database.singleProfile.current(), latest);
  });

  for (final legacyGeoPath in [false, true]) {
    test(
      'backups restore sealed provider and geo resources offline (legacy path: $legacyGeoPath)',
      () async {
        catalog = const [
          VpnServer(
            id: 'provider/subscription/QQ',
            name: 'A',
            target: 'A',
            type: 'Socks5',
            provider: 'subscription',
          ),
        ];
        const sourceYaml = '''
proxy-providers:
  subscription:
    type: file
    path: ignored.yaml
proxy-groups:
  - name: Pick
    type: select
    use: [subscription]
rules: ['MATCH,Pick']
''';
        final imported = await vpn.submit(
          VpnImportRequest(
            profile: profile,
            bytes: utf8.encode(sourceYaml),
            localOnly: true,
            localResource: (_, _, _) async => utf8.encode(yaml),
            resources: {
              'GeoSite.dat': [1, 2, 3],
            },
          ),
        );
        expect(
          imported.outcome,
          VpnImportOutcome.success,
          reason: '${imported.error}',
        );
        final old = imported.profile!;
        if (legacyGeoPath) {
          final generation = old.snapshot.generation!;
          await store
              .resource(generation, 'geo/GeoSite.dat')
              .rename(store.resource(generation, 'GeoSite.dat').path);
          final manifest = store.resource(generation, 'manifest.json');
          final metadata = jsonDecode(await manifest.readAsString()) as Map;
          final files = metadata['files'] as Map;
          files['GeoSite.dat'] = files.remove('geo/GeoSite.dat');
          await manifest.writeAsString(jsonEncode(metadata));
        }
        final archivePath = await action.backup();
        final entries = await VpnArchiveStore(home).verify(File(archivePath));
        expect(
          entries.keys,
          contains(
            'profiles/generations/${old.snapshot.generation}/${legacyGeoPath ? '' : 'geo/'}GeoSite.dat',
          ),
        );
        expect(
          entries.keys.any(
            (key) => key.contains('/providers/proxy-providers/'),
          ),
          isTrue,
        );
        final decoded = await readBackupArchive(
          backupFilePath: archivePath,
          restoreDirPath: '${staging.path}/decoded',
          homeDirPath: home.path,
        );
        expect(await database.singleProfile.current(), old);
        await action.applyRestore(decoded, RestoreOption.all);
        final restored = (await database.singleProfile.current())!;
        expect(restored.snapshot.generation, isNot(old.snapshot.generation));
        expect(restored.id, isNot(old.id));
        expect(await database.profilesDao.query().get(), [restored]);
        expect(await (await store.source(restored)).readAsString(), sourceYaml);
        expect(
          await store
              .resource(restored.snapshot.generation!, 'geo/GeoSite.dat')
              .readAsBytes(),
          [1, 2, 3],
        );
        expect(
          await VpnProfileResources(
            store,
          ).provider(restored, 'proxy-providers', 'subscription', {}),
          utf8.encode(yaml),
        );
      },
    );
  }

  test(
    'concurrent library edits cancel restore without losing the edit',
    () async {
      final previous = await current();
      await source(profile);
      final before = container.read(configProvider);
      when(() => core.activateConfig(any())).thenAnswer((invocation) async {
        const rule = Rule(id: 77, ruleTarget: 'DIRECT', content: 'new.example');
        await database.rules.put(rule.toCompanion());
        await database.profileRuleLinks.put(
          const ProfileRuleLink(ruleId: 77).toCompanion(),
        );
        final request =
            invocation.positionalArguments.single as ActivateConfigParams;
        final prepared = handles[request.prepared.handle]!;
        return ActivatedConfigResult(
          generation: prepared.generation,
          revision: prepared.revision,
        );
      });
      await expectLater(
        action.applyRestore(data(), RestoreOption.onlyProfiles),
        throwsA(isA<VpnImportCancelled>()),
      );
      expect(await database.singleProfile.current(), previous);
      expect(container.read(configProvider), before);
      expect(
        (await database.rulesDao.queryGlobalAddedRules().get()).single.id,
        77,
      );
    },
  );

  for (final strategy in RestoreStrategy.values) {
    test(
      'restore $strategy retains one profile and applies shared-data policy',
      () async {
        await current();
        container
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(restoreStrategy: strategy));
        await source(profile);
        await database.rules.put(
          const Rule(
            id: 77,
            ruleTarget: 'DIRECT',
            content: 'old.example',
          ).toCompanion(),
        );
        await database.profileRuleLinks.put(
          const ProfileRuleLink(ruleId: 77).toCompanion(),
        );
        await action.applyRestore(
          data().copyWith(
            rules: const [
              Rule(id: 88, ruleTarget: 'DIRECT', content: 'restored.example'),
            ],
            links: const [ProfileRuleLink(ruleId: 88)],
          ),
          RestoreOption.onlyProfiles,
        );
        final globals = await database.rulesDao.queryGlobalAddedRules().get();
        expect(
          globals.map((rule) => rule.content),
          unorderedEquals([
            if (strategy == RestoreStrategy.compatible) 'old.example',
            'restored.example',
          ]),
        );
        expect(await database.profilesDao.query().get(), hasLength(1));
      },
    );
  }

  for (final fails in [false, true]) {
    test(
      'consumeBackup removes only its temporary output (failure: $fails)',
      () async {
        final file = File('${home.path}/temporary.zip')
          ..writeAsBytesSync([80, 75, 5, 6]);
        final scoped = ProviderContainer(
          overrides: [
            backupActionProvider.overrideWith(() => _Archive(file.path)),
          ],
        );
        addTearDown(scoped.dispose);
        final operation = scoped
            .read(backupActionProvider.notifier)
            .consumeBackup((path) async {
              expect(path, file.path);
              if (fails) throw const SocketException('offline');
              return true;
            });
        if (fails) {
          await expectLater(operation, throwsA(isA<SocketException>()));
        } else {
          expect(await operation, isTrue);
        }
        expect(file.existsSync(), isFalse);
      },
    );
  }
}
