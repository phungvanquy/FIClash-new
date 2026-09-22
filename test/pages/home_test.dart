import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/vpn_import.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Setup extends SetupAction {
  final requests = <bool>[];
  Completer<bool>? gate;
  int statusChecks = 0;
  Completer<void>? statusGate;

  @override
  Future<void> syncRunState() async {
    statusChecks++;
    await statusGate?.future;
  }

  @override
  void build() {}

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    requests.add(running);
    return await gate?.future ?? true;
  }
}

class _Proxies extends ProxiesAction {
  final selections = <VpnSelection>[];
  Completer<bool>? gate;

  @override
  void build() {}

  @override
  Future<bool> selectVpn(VpnSelection selection) async {
    selections.add(selection);
    if (await gate?.future == false) return false;
    final profile = ref.read(currentProfileProvider)!;
    (ref.read(profilesProvider.notifier) as TestProfiles).replace([
      profile.copyWith.snapshot(
        selection: selection,
        routing: VpnRoutingMode.simple,
      ),
    ]);
    return true;
  }
}

class _Vpn extends VpnAction {
  Completer<bool>? gate;
  @override
  void build() {}

  @override
  Future<VpnImportResult> setRouting(
    Profile profile,
    VpnRoutingMode routing, {
    Mode? advancedMode,
    VpnSelection? selection,
  }) async {
    if (await gate?.future == false) {
      return const VpnImportResult(VpnImportOutcome.failed);
    }
    final updated = profile.copyWith.snapshot(
      routing: routing,
      advancedMode: advancedMode ?? profile.snapshot.advancedMode,
      selection: selection ?? profile.snapshot.selection,
    );
    (ref.read(profilesProvider.notifier) as TestProfiles).replace([updated]);
    return VpnImportResult(VpnImportOutcome.success, profile: updated);
  }
}

class _Latency extends VpnLatency {
  int calls = 0;
  Completer<void>? gate;

  @override
  VpnLatencyState build() => const VpnLatencyState();

  void publish(VpnLatencyState next) => state = next;

  @override
  Future<void> testAll() async {
    if (state.running) return;
    calls++;
    state = const VpnLatencyState(running: true);
    try {
      await gate?.future;
    } finally {
      state = const VpnLatencyState();
    }
  }
}

class _ActiveNode extends VpnActiveNode {
  @override
  AsyncValue<VpnServer?> build() => const AsyncData(null);

  void publish(VpnServer? server) => state = AsyncData(server);
}

Profile configured({int count = 3, bool custom = false}) => Profile(
  id: 1,
  autoUpdateDuration: const Duration(hours: 12),
  label: 'My VPN',
  url: 'https://provider.example/config?token=private',
  snapshot: ProfileSnapshot(
    revision: 1,
    generation: '0123456789abcdef0123456789abcdef',
    routing: custom ? VpnRoutingMode.custom : VpnRoutingMode.simple,
    servers: List.generate(
      count,
      (index) => VpnServer(
        id: 'server-$index',
        name: 'Server $index',
        target: 'Server $index',
        type: 'Vless',
      ),
    ),
    managedGroups: const VpnManagedGroups(
      selector: 'managed',
      auto: 'auto',
      fallback: 'fallback',
    ),
  ),
);

void main() {
  late ProviderContainer container;
  late _Setup setup;
  late _Proxies proxies;
  late _Vpn vpn;
  late _Latency latency;
  late _ActiveNode activeNode;

  setUpAll(() async => AppLocalizations.load(const Locale('en')));

  setUp(() {
    setup = _Setup();
    proxies = _Proxies();
    vpn = _Vpn();
    latency = _Latency();
    activeNode = _ActiveNode();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        setupActionProvider.overrideWith(() => setup),
        proxiesActionProvider.overrideWith(() => proxies),
        vpnActionProvider.overrideWith(() => vpn),
        vpnLatencyProvider.overrideWith(() => latency),
        vpnActiveNodeProvider.overrideWith(() => activeNode),
      ],
    );
    globalState.container = container;
    container.read(initProvider.notifier).value = true;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  });

  tearDown(() => container.dispose());

  void setProfile(Profile? profile) {
    (container.read(profilesProvider.notifier) as TestProfiles).replace([
      ?profile,
    ]);
    container.read(currentProfileIdProvider.notifier).value = profile?.id;
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1000, 800),
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: dark
                ? Theme(data: ThemeData.dark(), child: const HomePage())
                : const HomePage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void homeTest(String name, WidgetTesterCallback callback) {
    testWidgets(name, (tester) async {
      try {
        await callback(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      }
    });
  }

  homeTest(
    'empty Home offers explicit import choices without clipboard reads',
    (tester) async {
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') reads++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester);
      expect(find.byType(VpnImportPanel), findsOneWidget);
      expect(find.text('Paste from clipboard'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('vpn-connect')), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(reads, 0);
    },
  );

  homeTest('configured Home puts Auto, Fallback and leaf servers in one list', (
    tester,
  ) async {
    setProfile(configured());
    await pump(tester);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Fallback'), findsOneWidget);
    expect(find.text('Server 0'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byType(VpnImportPanel), findsNothing);
    await tester.tap(find.byKey(const Key('vpn-connect')));
    expect(setup.requests, [true]);
    expect(find.text('Connected'), findsNothing);
  });

  homeTest('connecting can be cancelled through the same action', (
    tester,
  ) async {
    setProfile(configured());
    container.read(vpnPendingProvider.notifier).value = true;
    await pump(tester);
    expect(find.text('Connecting...'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('vpn-connect')));
    expect(setup.requests, isEmpty);
    await tester.tap(find.byKey(const Key('vpn-cancel-connect')));
    expect(setup.requests, [false]);
  });

  homeTest('working system proxy is not labelled a VPN connection', (
    tester,
  ) async {
    setProfile(configured());
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          const CoreRunObservation(
            session: 'core',
            revision: 1,
            active: true,
            requested: true,
            mixedPort: 7890,
          ),
        );
    container.read(systemProxyStateProvider.notifier).value =
        const SystemProxyObservation(installed: true, port: 7890);
    await pump(tester);
    expect(find.text('Connected · system proxy only'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vpn-connect')));
    expect(setup.requests, [false]);
  });

  homeTest('connection and status use green when connected and gray when off', (
    tester,
  ) async {
    setProfile(configured());
    await pump(tester);
    Color? buttonColor() => tester
        .widget<FilledButton>(find.byKey(const Key('vpn-connect')))
        .style!
        .backgroundColor!
        .resolve({});
    Color? statusColor() =>
        tester.widget<Text>(find.byKey(const Key('vpn-status'))).style!.color;
    expect(buttonColor(), Colors.grey.shade800);
    expect(statusColor(), Colors.grey.shade800);
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          const CoreRunObservation(
            session: 'colors',
            revision: 1,
            requested: true,
            active: true,
            tun: true,
          ),
        );
    await tester.pump();
    expect(buttonColor(), const Color(0xFF00C853));
    expect(statusColor(), Colors.black);
    final badge = tester.widget<Container>(
      find.byKey(const Key('vpn-status-indicator')),
    );
    expect(
      (badge.decoration! as ShapeDecoration).color,
      const Color(0xFF00C853),
    );
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });

  homeTest('submitting and disconnecting disable repeated actions', (
    tester,
  ) async {
    setProfile(configured());
    setup.gate = Completer<bool>();
    await pump(tester);
    final button = find.byKey(const Key('vpn-connect'));
    await tester.tap(button);
    await tester.tap(button);
    expect(setup.requests, [true]);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    setup.gate!.complete(true);
    await tester.pump();
    container.read(vpnPendingProvider.notifier).value = false;
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('vpn-status'))).data,
      'Disconnecting…',
    );
    expect(find.byKey(const Key('vpn-cancel-connect')), findsNothing);
  });

  homeTest(
    'unavailable status offers guarded retry and safe Disconnect, never Connect',
    (tester) async {
      setProfile(configured());
      container.read(vpnFailureProvider.notifier).value = 'state_unavailable';
      setup.statusGate = Completer<void>();
      await pump(tester);
      expect(find.text('Connect'), findsNothing);
      expect(find.text('Disconnect'), findsOneWidget);
      final retry = find.byKey(const Key('vpn-retry-status'));
      await tester.tap(retry);
      await tester.pump();
      expect(tester.widget<TextButton>(retry).onPressed, isNull);
      await tester.tap(retry);
      expect(setup.statusChecks, 1);
      setup.statusGate!.complete();
      await tester.pump();
      expect(tester.widget<TextButton>(retry).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('vpn-connect')));
      expect(setup.requests, [false]);
    },
  );

  homeTest(
    'connected Home shows observed node and Auto mode, clears on disconnect',
    (tester) async {
      setProfile(configured());
      const connected = CoreRunObservation(
        session: 'current-node',
        revision: 1,
        active: true,
        tun: true,
      );
      container.read(coreRunStateProvider.notifier).observe(connected);
      await pump(tester);
      expect(find.text('Current node unavailable'), findsOneWidget);
      activeNode.publish(configured().snapshot.servers[1]);
      await tester.pump();
      final card = find.byKey(const Key('vpn-active-node'));
      expect(
        find.descendant(of: card, matching: find.text('Server 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Auto')),
        findsOneWidget,
      );
      activeNode.publish(configured().snapshot.servers[2]);
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('Server 2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Server 1')),
        findsNothing,
      );
      container
          .read(coreRunStateProvider.notifier)
          .observe(connected.copyWith(revision: 2, active: false));
      await tester.pump();
      expect(card, findsNothing);
    },
  );

  homeTest('custom routing does not claim all traffic uses one node', (
    tester,
  ) async {
    setProfile(configured(custom: true));
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          const CoreRunObservation(
            session: 'custom-current',
            revision: 1,
            active: true,
            tun: true,
          ),
        );
    await pump(tester, size: const Size(320, 640), scale: 1.8);
    expect(find.text('Nodes depend on routing rules'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  homeTest('failed disconnect is red and offers retry rather than Connect', (
    tester,
  ) async {
    setProfile(configured());
    container.read(vpnFailureProvider.notifier).value = 'stop_failed';
    await pump(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('vpn-status'))).style!.color,
      Colors.red.shade800,
    );
    expect(
      find.text('Could not confirm disconnection. Tap Disconnect to retry.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('vpn-connect')));
    expect(setup.requests, [false]);
  });

  homeTest('a rejected selection retains Auto and clears progress', (
    tester,
  ) async {
    setProfile(configured());
    proxies.gate = Completer<bool>();
    await pump(tester);
    await tester.tap(find.text('Server 0'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      container.read(currentProfileProvider)!.snapshot.selection,
      const VpnSelection.auto(),
    );
    proxies.gate!.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.textContaining('previous selection is unchanged'),
      findsOneWidget,
    );
  });

  homeTest('connection colors remain readable in the dark theme', (
    tester,
  ) async {
    setProfile(configured());
    await pump(tester, dark: true);
    expect(
      tester.widget<Text>(find.byKey(const Key('vpn-status'))).style!.color,
      Colors.grey.shade300,
    );
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          const CoreRunObservation(
            session: 'dark',
            revision: 1,
            requested: true,
            active: true,
            tun: true,
          ),
        );
    await tester.pump();
    final style = tester
        .widget<FilledButton>(find.byKey(const Key('vpn-connect')))
        .style!;
    expect(style.backgroundColor!.resolve({}), const Color(0xFF00C853));
    expect(style.foregroundColor!.resolve({}), Colors.black);
  });

  homeTest(
    'latency loading prevents duplicate tests and displays measured and failed nodes',
    (tester) async {
      setProfile(configured(count: 4));
      latency.gate = Completer<void>();
      await pump(tester);
      final button = find.byKey(const Key('vpn-test-latency'));
      expect(find.text('Not tested'), findsWidgets);
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(find.text('Testing…'), findsOneWidget);
      await tester.tap(button);
      expect(latency.calls, 1);
      latency.gate!.complete();
      await tester.pump();
      latency.publish(
        const VpnLatencyState(
          results: {
            'server-0': VpnNodeLatency(VpnLatencyStatus.measured, 18),
            'server-1': VpnNodeLatency(VpnLatencyStatus.timeout),
            'server-2': VpnNodeLatency(VpnLatencyStatus.unreachable),
            'server-3': VpnNodeLatency(VpnLatencyStatus.failed),
          },
        ),
      );
      await tester.pump();
      expect(find.text('18 ms'), findsOneWidget);
      final valueStyle = tester.widget<Text>(find.text('18 ms')).style!;
      expect(valueStyle.fontWeight, FontWeight.bold);
      expect(valueStyle.fontSize, greaterThanOrEqualTo(16));
      expect(find.text('Fastest'), findsOneWidget);
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Unreachable'), findsOneWidget);
      await tester.drag(
        find.byKey(const PageStorageKey('vpn-servers')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test failed'), findsOneWidget);
      expect(setup.requests, isEmpty);
      expect(proxies.selections, isEmpty);
      expect(
        container.read(currentProfileProvider)!.snapshot.selection,
        const VpnSelection.auto(),
      );
    },
  );

  homeTest('Home selection returns custom routing to simple mode', (
    tester,
  ) async {
    setProfile(configured(custom: true));
    await pump(tester);
    expect(find.text('Custom routing'), findsOneWidget);
    await tester.tap(find.text('Fallback'));
    await tester.pumpAndSettle();
    expect(
      container.read(currentProfileProvider)!.snapshot.routing,
      VpnRoutingMode.simple,
    );
    expect(
      container.read(currentProfileProvider)!.snapshot.selection,
      const VpnSelection.fallback(),
    );
    expect(find.text('Custom routing'), findsNothing);
  });

  homeTest('long server list scrolls independently of the connect control', (
    tester,
  ) async {
    setProfile(configured(count: 120));
    await pump(tester);
    final before = tester.getCenter(find.byKey(const Key('vpn-connect')));
    await tester.drag(
      find.byKey(const PageStorageKey('vpn-servers')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(const Key('vpn-connect'))), before);
    expect(find.text('Auto'), findsNothing);
  });

  for (final size in [
    const Size(320, 568),
    const Size(480, 320),
    const Size(1100, 800),
  ]) {
    homeTest('large text and ${size.width} layout do not overflow', (
      tester,
    ) async {
      setProfile(configured(count: 40));
      await pump(tester, size: size, scale: 2.5);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vpn-connect')), findsOneWidget);
      expect(find.byKey(const PageStorageKey('vpn-servers')), findsOneWidget);
    });
  }

  homeTest('gear opens Settings and back preserves the connection', (
    tester,
  ) async {
    setProfile(configured());
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          const CoreRunObservation(
            session: 'core',
            revision: 1,
            active: true,
            requested: true,
            tun: true,
          ),
        );
    await pump(tester);
    await tester.tap(find.byKey(const Key('vpn-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(ToolsView), findsOneWidget);
    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.byType(ProfilesView), findsNothing);
    Navigator.of(tester.element(find.byType(ToolsView))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(setup.requests, isEmpty);
  });

  homeTest('replacement is a compact entry with the same intake panel', (
    tester,
  ) async {
    setProfile(configured());
    await pump(tester);
    await tester.tap(find.text('Replace configuration'));
    await tester.pumpAndSettle();
    expect(find.byType(VpnImportPanel), findsOneWidget);
    expect(
      tester.widget<VpnImportPanel>(find.byType(VpnImportPanel)).replacement,
      isTrue,
    );
  });

  homeTest(
    'Settings routing toggle waits for commit and retains state on failure',
    (tester) async {
      setProfile(configured());
      vpn.gate = Completer<bool>();
      await pump(tester);
      await tester.tap(find.byKey(const Key('vpn-settings')));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('vpn-custom-routing'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      vpn.gate!.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(
        container.read(currentProfileProvider)!.snapshot.routing,
        VpnRoutingMode.simple,
      );
      expect(
        find.textContaining('operation could not be completed'),
        findsOneWidget,
      );
    },
  );

  homeTest('resizing Home retains the committed server selection', (
    tester,
  ) async {
    setProfile(configured());
    await pump(tester);
    await tester.tap(find.text('Server 1'));
    await tester.pumpAndSettle();
    await pump(tester, size: const Size(360, 740));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey(VpnSelection.server('server-1'))),
      100,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('vpn-servers')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      container.read(currentProfileProvider)!.snapshot.selection,
      const VpnSelection.server('server-1'),
    );
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey(VpnSelection.server('server-1'))),
          )
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  homeTest('connect and Settings have accessible names and keyboard focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    setProfile(configured());
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('Connect')), findsWidgets);
    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ToolsView), findsOneWidget);
    handle.dispose();
  });
}
