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
import 'package:yaml/yaml.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _UpdateParams extends Fake implements UpdateParams {}

class _VpnAction extends VpnAction {
  @override
  Future<Map<String, dynamic>> prepareOverrides(
    Profile profile,
    Map<String, dynamic> source, {
    db.ProfileOwnedData? ownedData,
  }) async => source;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = Profile(
    id: 1,
    label: 'VPN',
    autoUpdateDuration: Duration(hours: 1),
  );
  const servers = [
    VpnServer(id: 'inline/QQ', name: 'A', target: 'A', type: 'Socks5'),
  ];
  final bytes = utf8.encode(
    'proxies: [{name: A, type: socks5, server: 127.0.0.1, port: 1080}]',
  );
  late Directory home;
  late db.Database database;
  late ProfileGenerationStore store;
  late ProviderContainer container;
  late _Core core;
  late VpnAction action;
  late Map<String, PrepareConfigParams> prepared;
  late VpnResourceFetch fetch;
  late List<String> fetched;
  late List<VpnServer> catalog;
  var running = false;
  var activations = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.load(const Locale('en'));
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
    registerFallbackValue(_UpdateParams());
    registerFallbackValue(
      const ChangeProxyParams(groupName: '', proxyName: ''),
    );
  });

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-action-test-');
    database = db.Database(NativeDatabase.memory());
    db.database = database;
    store = ProfileGenerationStore(home);
    core = _Core();
    when(() => core.isInit).thenAnswer((_) async => true);
    prepared = {};
    running = false;
    activations = 0;
    fetched = [];
    catalog = servers;
    fetch = (url, headers, cancel) async {
      fetched.add(url);
      return VpnDownload(bytes);
    };
    when(() => core.prepareConfig(any())).thenAnswer((invocation) async {
      final params =
          invocation.positionalArguments.single as PrepareConfigParams;
      final handle = 'handle-${prepared.length}';
      prepared[handle] = params;
      return PreparedConfigResult(
        handle: handle,
        generation: params.generation,
        revision: params.revision,
        servers: catalog,
      );
    });
    when(() => core.discardConfig(any())).thenAnswer((_) async => true);
    when(() => core.activateConfig(any())).thenAnswer((invocation) async {
      activations++;
      final params =
          invocation.positionalArguments.single as ActivateConfigParams;
      final staged = prepared[params.prepared.handle]!;
      return ActivatedConfigResult(
        generation: staged.generation,
        revision: staged.revision,
      );
    });
    when(
      () => core.getProxies(),
    ).thenAnswer((_) async => const ProxiesData(proxies: {}, all: []));
    when(() => core.getExternalProviders()).thenAnswer((_) async => []);
    when(() => core.setupConfig(any())).thenAnswer((_) async => '');
    when(() => core.updateConfig(any())).thenAnswer((_) async => '');
    when(() => core.stopListener()).thenAnswer((_) async {
      running = false;
      return true;
    });
    when(() => core.resetTraffic()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profileGenerationStoreProvider.overrideWith((_) async => store),
        singleProfileRepositoryProvider.overrideWithValue(
          database.singleProfile,
        ),
        vpnActionProvider.overrideWith(_VpnAction.new),
        vpnResourceFetchProvider.overrideWith(
          (_) =>
              (url, headers, cancel) => fetch(url, headers, cancel),
        ),
      ],
    );
    container.listen(configProvider, (_, _) {});
    container.listen(sharedStateProvider, (_, _) {});
    action = container.read(vpnActionProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    await home.delete(recursive: true);
  });

  Future<VpnImportResult> submit([Profile candidate = profile]) =>
      action.submit(VpnImportRequest(profile: candidate, bytes: bytes));

  test(
    'import, select, connect, replace and reject preserve a running snapshot',
    () async {
      var observationRevision = 0;
      when(() => core.startListener()).thenAnswer((_) async {
        running = true;
        return true;
      });
      when(() => core.getRunState()).thenAnswer(
        (_) async => CoreRunObservation(
          session: 'integration',
          revision: ++observationRevision,
          requested: running,
          active: running,
          tun: running,
          mixedPort: 7890,
        ),
      );
      when(() => core.changeProxy(any())).thenAnswer((_) async => '');
      when(() => core.resetConnections()).thenAnswer((_) async => true);
      when(() => core.closeConnections()).thenAnswer((_) async => true);
      when(
        () => core.getTraffic(any()),
      ).thenAnswer((_) async => const Traffic());
      when(
        () => core.getTotalTraffic(any()),
      ).thenAnswer((_) async => const Traffic());
      container.read(initProvider.notifier).value = true;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      container.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;
      container
          .read(appSettingProvider.notifier)
          .update((value) => value.copyWith(vpnDefaultsPending: false));
      container
          .read(patchClashConfigProvider.notifier)
          .update((value) => value.copyWith.tun(enable: true));
      final setup = container.read(setupActionProvider.notifier);
      final first = await action.importUrl(
        'https://provider.example/config?token=first',
      );
      expect(first.outcome, VpnImportOutcome.success);
      expect(running, isFalse);
      expect(
        container.read(vpnConnectionProvider).phase,
        VpnConnectionPhase.disconnected,
      );
      verifyNever(() => core.startListener());
      expect(
        await container
            .read(proxiesActionProvider.notifier)
            .selectVpn(const VpnSelection.server('inline/QQ')),
        isTrue,
      );
      expect(
        (await database.singleProfile.current())!.snapshot.selection,
        const VpnSelection.server('inline/QQ'),
      );
      expect(await setup.setRunning(true), isTrue);
      expect(
        container.read(vpnConnectionProvider).phase,
        VpnConnectionPhase.connected,
      );
      final replacement = await action.importUrl(
        'https://provider.example/config?token=next',
      );
      expect(replacement.outcome, VpnImportOutcome.success);
      expect(
        replacement.profile!.snapshot.revision,
        first.profile!.snapshot.revision + 1,
      );
      expect(running, isTrue);
      expect(
        container.read(vpnConnectionProvider).phase,
        VpnConnectionPhase.connected,
      );
      final runtime = await store.runtimeBytes();
      fetch = (_, _, _) async => throw const SocketException('offline');
      final rejected = await action.importUrl(
        'https://provider.example/config?token=bad',
      );
      expect(rejected.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), replacement.profile);
      expect(await store.runtimeBytes(), runtime);
      expect(running, isTrue);
      await setup.setRunning(false);
      expect(
        container.read(vpnConnectionProvider).phase,
        VpnConnectionPhase.disconnected,
      );
      expect(await database.profilesDao.query().get(), hasLength(1));
    },
  );

  test(
    'one activation publishes one profile and durable native mirrors',
    () async {
      final result = await submit();
      expect(result.outcome, VpnImportOutcome.success);
      expect(activations, 1);
      expect(running, isFalse);
      expect(container.read(currentProfileProvider), result.profile);
      expect(await database.singleProfile.current(), result.profile);
      expect((await preferences.getConfig())?.currentProfileId, profile.id);
      final preferencesStore = await SharedPreferences.getInstance();
      final shared = SharedState.fromJson(
        jsonDecode(preferencesStore.getString('sharedState')!)
            as Map<String, dynamic>,
      );
      expect(
        shared.setupParams?.generation,
        result.profile?.snapshot.generation,
      );
      expect(
        shared.setupParams?.selectedMap,
        vpnRuntimeSelections(result.profile!),
      );
      verifyNever(() => core.startListener());
      verifyNever(() => core.setupConfig(any()));
      expect(await store.pending(), isNull);
    },
  );

  test(
    'initialization migrates one profile before permitting automatic setup',
    () async {
      final first = profile.copyWith(order: 0);
      final second = profile.copyWith(id: 2, order: 1);
      await database.profilesDao.setAll([first, second]);
      for (final item in [first, second]) {
        final source = File('${home.path}/profiles/${item.id}.yaml');
        await source.parent.create(recursive: true);
        await source.writeAsBytes(bytes);
      }
      container.read(profilesProvider.notifier).showSingleProfile(second);
      container.read(currentProfileIdProvider.notifier).value = second.id;
      final result = await action.initialize();
      expect(result.complete, isTrue);
      expect(result.profile?.id, 2);
      expect(result.archive, isNotNull);
      expect(container.read(vpnMigrationStateProvider), same(result));
      expect(container.read(profilesProvider), [result.profile]);
      expect(await database.profilesDao.query().get(), [result.profile]);
      expect(await action.initialize(), same(result));
      expect(activations, 1);
      verifyNever(() => core.startListener());
    },
  );

  test(
    'unavailable Core leaves migration pending and can be retried',
    () async {
      when(() => core.isInit).thenAnswer((_) async => false);
      final first = await action.initialize();
      expect(first.complete, isFalse);
      expect((await database.singleProfile.state()).migrationVersion, 0);
      when(() => core.isInit).thenAnswer((_) async => true);
      final second = await action.initialize();
      expect(second.complete, isTrue);
      expect(second.profile, isNull);
      expect((await database.singleProfile.state()).migrationVersion, 1);
      verifyNever(() => core.prepareConfig(any()));
    },
  );

  test('only stale handles are re-prepared from sealed local bytes', () async {
    var stale = true;
    when(() => core.activateConfig(any())).thenAnswer((invocation) async {
      activations++;
      if (stale) {
        stale = false;
        throw const CoreMethodException(
          code: 'stale_preparation',
          message: 'stale',
        );
      }
      final params =
          invocation.positionalArguments.single as ActivateConfigParams;
      final staged = prepared[params.prepared.handle]!;
      return ActivatedConfigResult(
        generation: staged.generation,
        revision: staged.revision,
      );
    });
    final result = await submit();
    expect(result.outcome, VpnImportOutcome.success);
    expect(prepared, hasLength(3));
    expect(activations, 2);
    verifyNever(() => core.setupConfig(any()));
  });

  test(
    'custom and simple routing round trip offline without losing advanced choices',
    () async {
      final first = (await submit(
        profile.copyWith(selectedMap: {'Original': 'A'}),
      )).profile!;
      final custom = await action.setRouting(
        first,
        VpnRoutingMode.custom,
        advancedMode: Mode.rule,
      );
      expect(custom.outcome, VpnImportOutcome.success);
      expect(custom.profile!.selectedMap, first.selectedMap);
      expect(
        loadYaml(utf8.decode((await store.runtimeBytes())!))['mode'],
        'rule',
      );
      final simple = await action.setRouting(
        custom.profile!,
        VpnRoutingMode.simple,
        selection: const VpnSelection.server('inline/QQ'),
      );
      expect(simple.outcome, VpnImportOutcome.success);
      expect(simple.profile!.selectedMap, first.selectedMap);
      expect(simple.profile!.snapshot.advancedMode, Mode.rule);
      expect(
        simple.profile!.snapshot.selection,
        const VpnSelection.server('inline/QQ'),
      );
      expect(
        loadYaml(utf8.decode((await store.runtimeBytes())!))['mode'],
        'global',
      );
      expect(fetched, isEmpty);
      verifyNever(() => core.startListener());
    },
  );

  test(
    'URL imports replace the sole profile and preserve embedded credentials',
    () async {
      final first = (await submit()).profile!;
      final progress = <VpnImportStep>[];
      final result = await action.importUrl(
        'https://example.test/config?token=a%2Fb',
        onProgress: (value) => progress.add(value.step),
      );
      expect(result.outcome, VpnImportOutcome.success);
      expect(fetched, ['https://example.test/config?token=a%2Fb']);
      expect(await database.profilesDao.query().get(), [result.profile]);
      expect(result.profile!.snapshot.revision, first.snapshot.revision + 1);
      expect(result.profile!.snapshot.selection, const VpnSelection.auto());
      expect(progress.first, VpnImportStep.download);
      expect(progress.last, VpnImportStep.finalizing);
      progress.clear();
      final refreshed = await action.refresh(
        result.profile!,
        onProgress: (value) => progress.add(value.step),
      );
      expect(refreshed.outcome, VpnImportOutcome.success);
      expect(progress.first, VpnImportStep.download);
      expect(progress.last, VpnImportStep.finalizing);
    },
  );

  test(
    'failed edited URL preserves profile, timestamp, and generation bytes',
    () async {
      final first = (await submit()).profile!;
      final runtime = await store.runtimeBytes();
      fetch = (_, _, _) async => throw const SocketException('offline');
      final result = await action.edit(
        first.copyWith(url: 'https://example.test/new'),
      );
      expect(result.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), first);
      expect(await store.runtimeBytes(), runtime);
      expect(container.read(currentProfileProvider), first);
      expect(activations, 1);
    },
  );

  test(
    'refresh falls back to Auto only after successfully replacing a removed server',
    () async {
      final first = (await submit(
        profile.copyWith(
          url: 'https://example.test/config',
          snapshot: const ProfileSnapshot(
            selection: VpnSelection.server('inline/QQ'),
          ),
        ),
      )).profile!;
      fetch = (_, _, _) async => VpnDownload(
        utf8.encode(
          'proxies: [{name: B, type: socks5, server: 127.0.0.1, port: 1081}]',
        ),
      );
      catalog = [];
      final failed = await action.refresh(first);
      expect(failed.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), first);
      catalog = [
        const VpnServer(
          id: 'inline/Qg',
          name: 'B',
          target: 'B',
          type: 'Socks5',
        ),
      ];
      final result = await action.refresh(first);
      expect(result.outcome, VpnImportOutcome.success);
      expect(result.profile!.snapshot.selection, const VpnSelection.auto());
      expect(result.profile!.snapshot.servers.single.name, 'B');
      expect(result.profile!.snapshot.revision, first.snapshot.revision + 1);
    },
  );

  test(
    'provider refresh and side-load stage resources instead of invoking native writers',
    () async {
      final source = utf8.encode(
        '${utf8.decode(bytes)}\nproxy-providers: '
        '{remote: {type: http, url: https://example.test/provider, interval: 3600}}',
      );
      final first = (await action.submit(
        VpnImportRequest(profile: profile, bytes: source),
      )).profile!;
      fetched.clear();
      final provider = ExternalProvider(
        name: 'remote',
        type: 'Proxy',
        count: 1,
        vehicleType: 'HTTP',
        updateAt: DateTime.utc(2026),
      );
      final proxies = container.read(proxiesActionProvider.notifier);
      expect(await proxies.updateProvider(provider), '');
      final refreshed = (await database.singleProfile.current())!;
      expect(fetched, ['https://example.test/provider']);
      expect(refreshed.lastUpdateDate, first.lastUpdateDate);
      expect(refreshed.snapshot.revision, first.snapshot.revision + 1);
      fetched.clear();
      expect(
        await proxies.sideLoadExternalProvider(provider, 'proxies: []'),
        '',
      );
      final edited = (await database.singleProfile.current())!;
      expect(edited.snapshot.revision, refreshed.snapshot.revision + 1);
      expect(fetched, isEmpty);
      expect(
        utf8.decode(
          await VpnProfileResources(
            store,
          ).provider(edited, 'proxy-providers', 'remote', {}),
        ),
        'proxies: []',
      );
      verifyNever(() => core.updateExternalProvider(any()));
    },
  );

  test(
    'offline edit stages a new generation without changing fetch time',
    () async {
      final first = (await submit()).profile!;
      final result = await action.edit(first.copyWith(matchTarget: 'A'));
      expect(result.outcome, VpnImportOutcome.success);
      expect(
        result.profile!.snapshot.generation,
        isNot(first.snapshot.generation),
      );
      expect(result.profile!.lastUpdateDate, first.lastUpdateDate);
      expect(result.profile!.matchTarget, 'A');
      expect(fetched, isEmpty);
    },
  );

  test('metadata updates cannot bypass configuration staging', () async {
    final first = (await submit()).profile!;
    final renamed = first.copyWith(label: 'Renamed');
    await action.updateMetadata(renamed);
    expect(await database.singleProfile.current(), renamed);
    expect(activations, 1);
    await expectLater(
      action.updateMetadata(renamed.copyWith(url: 'https://example.test/new')),
      throwsA(isA<db.StaleProfileRevision>()),
    );
    expect(await database.singleProfile.current(), renamed);
  });

  test('old editor and disposal cannot override a newer import', () async {
    final first = (await submit()).profile!;
    final revision = action.requestRevision;
    final replacement = (await submit(profile.copyWith(id: 2))).profile!;
    action.cancelIfCurrent(revision);
    expect((await action.edit(first)).outcome, VpnImportOutcome.cancelled);
    expect(await database.singleProfile.current(), replacement);
    expect(activations, 2);
  });

  test(
    'unexpected activation acknowledgement rolls back without committing',
    () async {
      final first = (await submit()).profile!;
      when(() => core.activateConfig(any())).thenAnswer(
        (_) async =>
            const ActivatedConfigResult(generation: 'wrong', revision: 999),
      );
      final result = await submit(profile.copyWith(id: 2));
      expect(result.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), first);
      verify(() => core.setupConfig(any())).called(1);
    },
  );

  test(
    'setup reuses the committed generation and preserves simple routing',
    () async {
      final result = await submit();
      final committed = result.profile!;
      final setup = container.read(setupActionProvider.notifier);
      expect(await setup.applyProfile(force: true), isTrue);
      final params =
          verify(() => core.setupConfig(captureAny())).captured.single
              as SetupParams;
      expect(params.generation, committed.snapshot.generation);
      expect(params.revision, committed.snapshot.revision);
      final updates =
          verify(() => core.updateConfig(captureAny())).captured.single
              as UpdateParams;
      expect(updates.mode, Mode.global);
      expect(updates.tun.enable, isFalse);
      expect(
        await store.runtimeBytes(),
        await store
            .resource(committed.snapshot.generation!, 'effective.yaml')
            .readAsBytes(),
      );
      expect(await store.load(committed.snapshot.generation!), committed);
      verifyNever(() => core.startListener());
      verifyNever(() => core.getConfig(any()));
    },
  );

  test(
    'failed first activation restores the explicit empty configuration',
    () async {
      when(() => core.activateConfig(any())).thenThrow(
        const CoreMethodException(
          code: 'activation_failed',
          message: 'bind failed',
        ),
      );
      when(() => core.setupConfig(any())).thenAnswer((_) async {
        expect(utf8.decode((await store.runtimeBytes())!), '{}\n');
        return '';
      });
      final result = await submit();
      expect(result.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), isNull);
      expect(await store.runtimeBytes(), isNull);
      expect(await store.pending(), isNull);
      expect(prepared, hasLength(2));
    },
  );

  test(
    'disconnect during activation is not replaced by captured running intent',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      running = true;
      when(() => core.activateConfig(any())).thenAnswer((invocation) async {
        entered.complete();
        await release.future;
        final params =
            invocation.positionalArguments.single as ActivateConfigParams;
        final staged = prepared[params.prepared.handle]!;
        return ActivatedConfigResult(
          generation: staged.generation,
          revision: staged.revision,
        );
      });
      final pending = submit();
      await entered.future;
      await container.read(setupActionProvider.notifier).setRunning(false);
      release.complete();
      expect((await pending).outcome, VpnImportOutcome.success);
      expect(running, isFalse);
      verifyNever(() => core.startListener());
    },
  );

  test('settings changes during preparation cancel the candidate', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    when(() => core.prepareConfig(any())).thenAnswer((invocation) async {
      entered.complete();
      await release.future;
      final params =
          invocation.positionalArguments.single as PrepareConfigParams;
      return PreparedConfigResult(
        handle: 'stale-settings',
        generation: params.generation,
        revision: params.revision,
        servers: servers,
      );
    });
    final pending = submit();
    await entered.future;
    container
        .read(patchClashConfigProvider.notifier)
        .update((value) => value.copyWith(mixedPort: value.mixedPort + 1));
    release.complete();
    expect((await pending).outcome, VpnImportOutcome.cancelled);
    expect(await database.singleProfile.current(), isNull);
    verifyNever(() => core.activateConfig(any()));
  });

  test(
    'override records are committed only after successful activation',
    () async {
      final previous = (await submit()).profile!;
      const rule = Rule(id: 91, ruleAction: RuleAction.MATCH, ruleTarget: 'A');
      const owned = db.ProfileOwnedData(
        rules: [rule],
        links: [
          ProfileRuleLink(profileId: 1, ruleId: 91, scene: RuleScene.custom),
        ],
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      when(() => core.activateConfig(any())).thenAnswer((invocation) async {
        entered.complete();
        await release.future;
        final params =
            invocation.positionalArguments.single as ActivateConfigParams;
        final staged = prepared[params.prepared.handle]!;
        return ActivatedConfigResult(
          generation: staged.generation,
          revision: staged.revision,
        );
      });
      final pending = action.edit(
        previous.copyWith(overwriteType: OverwriteType.custom),
        expected: previous,
        ownedData: owned,
      );
      await entered.future;
      expect(await database.singleProfile.current(), previous);
      expect((await database.singleProfile.ownedData(1)).rules, isEmpty);
      release.complete();
      final result = await pending;
      expect(result.outcome, VpnImportOutcome.success);
      expect(result.profile!.snapshot.revision, previous.snapshot.revision + 1);
      expect((await database.singleProfile.ownedData(1)).rules, [rule]);
      expect(
        (await database.singleProfile.current())?.overwriteType,
        OverwriteType.custom,
      );
    },
  );

  test(
    'rejected override draft preserves owned data and active snapshot',
    () async {
      final previous = (await submit()).profile!;
      final runtime = await store.runtimeBytes();
      when(() => core.prepareConfig(any())).thenThrow(
        const CoreMethodException(
          code: 'prepare_failed',
          message: 'Invalid rule',
        ),
      );
      final result = await action.edit(
        previous.copyWith(matchTarget: 'Missing'),
        expected: previous,
        ownedData: const db.ProfileOwnedData(
          rules: [Rule(id: 91, ruleTarget: 'Missing')],
          links: [
            ProfileRuleLink(profileId: 1, ruleId: 91, scene: RuleScene.added),
          ],
        ),
      );
      expect(result.outcome, VpnImportOutcome.failed);
      expect(await database.singleProfile.current(), previous);
      expect((await database.singleProfile.ownedData(1)).rules, isEmpty);
      expect(await store.runtimeBytes(), runtime);
      expect(activations, 1);
    },
  );

  test(
    'metadata changed during draft preparation cannot be overwritten',
    () async {
      final previous = (await submit()).profile!;
      final entered = Completer<void>();
      final release = Completer<void>();
      when(() => core.prepareConfig(any())).thenAnswer((invocation) async {
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        final params =
            invocation.positionalArguments.single as PrepareConfigParams;
        final handle = 'metadata-${prepared.length}';
        prepared[handle] = params;
        return PreparedConfigResult(
          handle: handle,
          generation: params.generation,
          revision: params.revision,
          servers: servers,
        );
      });
      final pending = action.edit(
        previous.copyWith(matchTarget: 'A'),
        expected: previous,
      );
      await entered.future;
      final latest = previous.copyWith(label: 'Renamed while editing');
      await action.updateMetadata(latest);
      release.complete();
      expect((await pending).outcome, VpnImportOutcome.cancelled);
      expect(await database.singleProfile.current(), latest);
      expect(activations, 1);
    },
  );

  test(
    'failed preference mirror remains repairable after a successful commit',
    () async {
      final previousPreferences = preferences.sharedPreferencesCompleter;
      preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
        ..complete(null);
      addTearDown(
        () => preferences.sharedPreferencesCompleter = previousPreferences,
      );
      final result = await submit();
      expect(result.outcome, VpnImportOutcome.success);
      expect(await database.singleProfile.current(), result.profile);
      expect(await store.pending(), isNotNull);
      preferences.sharedPreferencesCompleter = previousPreferences;
      await action.recover();
      expect(await store.pending(), isNull);
      expect(
        (await preferences.getConfig())?.currentProfileId,
        result.profile?.id,
      );
    },
  );

  test('cancel before coordinator initialization cannot submit', () async {
    final gate = Completer<ProfileGenerationStore>();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        profileGenerationStoreProvider.overrideWith((_) => gate.future),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        singleProfileRepositoryProvider.overrideWithValue(
          database.singleProfile,
        ),
      ],
    );
    action = container.read(vpnActionProvider.notifier);
    final pending = submit();
    action.cancel();
    gate.complete(store);
    expect((await pending).outcome, VpnImportOutcome.cancelled);
    verifyNever(() => core.prepareConfig(any()));
  });

  test(
    'a post-commit recovery check cannot report the durable import as failed',
    () async {
      store = ProfileGenerationStore(
        home,
        checkpoint: (point) async {
          if (point != ProfileStoreCheckpoint.journalRemoved) return;
          container.read(vpnFailureProvider.notifier).value =
              'recovery_required';
          await File(
            '${home.path}/profile-commit.json',
          ).writeAsString('unreadable journal');
        },
      );
      final result = await submit();
      expect(result.outcome, VpnImportOutcome.success);
      expect(await database.singleProfile.current(), result.profile);
      expect(container.read(vpnFailureProvider), 'recovery_required');
      expect(await store.runtimeBytes(), isNotNull);
    },
  );
}
