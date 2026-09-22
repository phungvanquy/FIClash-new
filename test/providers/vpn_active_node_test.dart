import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Core core;
  late ProviderContainer container;
  late Profile profile;
  late CoreRunObservation observation;
  late ProxiesData data;

  setUp(() {
    core = _Core();
    profile = const Profile(
      id: 1,
      autoUpdateDuration: Duration.zero,
      snapshot: ProfileSnapshot(
        generation: 'first',
        managedGroups: VpnManagedGroups(
          selector: 'managed',
          auto: 'auto',
          fallback: 'fallback',
        ),
        servers: [
          VpnServer(
            id: 'a',
            name: 'Duplicate',
            target: 'alias-a',
            type: 'Vless',
            provider: 'one',
          ),
          VpnServer(
            id: 'b',
            name: 'Duplicate',
            target: 'alias-b',
            type: 'Vless',
            provider: 'two',
          ),
        ],
      ),
    );
    observation = const CoreRunObservation(
      session: 'core',
      revision: 1,
      active: true,
      tun: true,
      generation: 'first',
      configRevision: 1,
    );
    data = const ProxiesData(
      all: [],
      proxies: {
        'GLOBAL': {'now': 'managed'},
        'managed': {'now': 'auto'},
        'auto': {'now': 'alias-a'},
        'fallback': {'now': 'alias-b'},
      },
    );
    when(core.getRunState).thenAnswer((_) async => observation);
    when(core.getProxies).thenAnswer((_) async => data);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => 1),
      ],
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(coreRunStateProvider.notifier).observe(observation);
  });

  tearDown(() => container.dispose());

  void nodeTest(String name, WidgetTesterCallback callback) {
    testWidgets(name, (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      container.listen(vpnActiveNodeProvider, (_, _) {});
      try {
        await callback(tester);
      } finally {
        container.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }
    });
  }

  VpnServer? node() => container.read(vpnActiveNodeProvider).asData?.value;
  void replace(Profile next) {
    (container.read(profilesProvider.notifier) as TestProfiles).replace([next]);
    container.read(vpnActiveNodeProvider);
  }

  nodeTest('observes Auto failover without changing selection or VPN', (
    tester,
  ) async {
    await tester.pump();
    expect(node()?.id, 'a');
    expect(node()?.provider, 'one');
    data = data.copyWith(
      proxies: {
        ...data.proxies,
        'auto': {'now': 'alias-b'},
      },
    );
    await tester.pump(const Duration(seconds: 5));
    expect(node()?.id, 'b');
    expect(container.read(currentProfileProvider), profile);
    expect(container.read(vpnRunRequestedProvider), isFalse);
    verify(core.getProxies).called(2);
    verify(core.getRunState).called(4);
    verifyNoMoreInteractions(core);
  });

  nodeTest('manual and Fallback use Core now, not persisted choice', (
    tester,
  ) async {
    replace(
      profile.copyWith.snapshot(selection: const VpnSelection.fallback()),
    );
    data = data.copyWith(
      proxies: {
        ...data.proxies,
        'managed': {'now': 'fallback'},
      },
    );
    await tester.pump();
    expect(node()?.id, 'b');
    replace(
      profile.copyWith.snapshot(selection: const VpnSelection.server('a')),
    );
    await tester.pump();
    expect(node(), isNull);
    data = data.copyWith(
      proxies: {
        ...data.proxies,
        'managed': {'now': 'alias-a'},
      },
    );
    await tester.pump(const Duration(seconds: 5));
    expect(node()?.id, 'a');
  });

  nodeTest('missing and cyclic targets never become a claimed current node', (
    tester,
  ) async {
    data = data.copyWith(
      proxies: {
        ...data.proxies,
        'auto': {'now': 'auto'},
      },
    );
    await tester.pump();
    expect(node(), isNull);
    data = data.copyWith(
      proxies: {
        ...data.proxies,
        'auto': {'now': 'unknown'},
      },
    );
    await tester.pump(const Duration(seconds: 5));
    expect(node(), isNull);
  });

  nodeTest('times out visibly without overlapping slow queries, then retries', (
    tester,
  ) async {
    final gate = Completer<ProxiesData>();
    when(core.getProxies).thenAnswer((_) => gate.future);
    await tester.pump();
    expect(container.read(vpnActiveNodeProvider).isLoading, isTrue);
    await tester.pump(const Duration(seconds: 20));
    expect(container.read(vpnActiveNodeProvider).isLoading, isFalse);
    expect(node(), isNull);
    verify(core.getProxies).called(1);
    gate.complete(data);
    await tester.pump();
    expect(node(), isNull);
    when(core.getProxies).thenAnswer((_) async => data);
    await tester.pump(const Duration(seconds: 5));
    expect(node()?.id, 'a');
  });

  nodeTest('RPC failure clears previous current node', (tester) async {
    await tester.pump();
    expect(node()?.id, 'a');
    when(core.getProxies).thenThrow(StateError('offline'));
    await tester.pump(const Duration(seconds: 5));
    expect(node(), isNull);
    expect(container.read(vpnActiveNodeProvider).isLoading, isFalse);
  });

  nodeTest(
    'Settings pauses current-node polling and Home refreshes on return',
    (tester) async {
      await tester.pump();
      expect(node()?.id, 'a');
      container.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
      container.read(vpnActiveNodeProvider);
      await tester.pump(const Duration(seconds: 20));
      expect(node(), isNull);
      verify(core.getProxies).called(1);
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.dashboard);
      container.read(vpnActiveNodeProvider);
      await tester.pump();
      expect(node()?.id, 'a');
      verify(core.getProxies).called(1);
    },
  );

  nodeTest('background pauses reads and resume refreshes', (tester) async {
    await tester.pump();
    expect(node()?.id, 'a');
    for (final phase in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(phase);
    }
    await tester.pump(const Duration(seconds: 20));
    expect(node(), isNull);
    verify(core.getProxies).called(1);
    for (final phase in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(phase);
    }
    await tester.pump();
    expect(node()?.id, 'a');
    verify(core.getProxies).called(1);
  });

  for (final change in ['disconnect', 'generation', 'custom', 'dispose']) {
    nodeTest('ignores in-flight node after $change', (tester) async {
      final gate = Completer<ProxiesData>();
      when(core.getProxies).thenAnswer((_) => gate.future);
      await tester.pump();
      switch (change) {
        case 'disconnect':
          container
              .read(coreRunStateProvider.notifier)
              .observe(observation.copyWith(revision: 2, active: false));
        case 'generation':
          replace(profile.copyWith.snapshot(generation: 'second'));
        case 'custom':
          replace(profile.copyWith.snapshot(routing: VpnRoutingMode.custom));
        case 'dispose':
          container.dispose();
      }
      await tester.pump();
      gate.complete(data);
      await tester.pump();
      if (change != 'dispose') expect(node(), isNull);
    });
  }

  nodeTest('rejects Core restart or generation replacement during query', (
    tester,
  ) async {
    when(core.getProxies).thenAnswer((_) async {
      observation = observation.copyWith(
        session: 'new-core',
        generation: 'second',
      );
      return data;
    });
    await tester.pump();
    expect(node(), isNull);
  });
}
