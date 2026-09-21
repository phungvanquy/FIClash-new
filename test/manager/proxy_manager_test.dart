import 'dart:async';

import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/proxy_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/proxy.dart' as platform;

import '../helpers/test_app.dart';

class _Proxy extends platform.Proxy {
  final calls = <int>[];
  bool success = true;
  Completer<bool>? startGate;

  @override
  Future<bool> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    calls.add(port);
    return await startGate?.future ?? success;
  }

  @override
  Future<bool> stopProxy() async {
    calls.add(0);
    return success;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _Proxy proxy;
  var revision = 0;

  setUp(() {
    proxy = _Proxy();
    container = ProviderContainer(
      overrides: [systemProxyAdapterProvider.overrideWithValue(proxy)],
    );
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pumpProxyManager(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: ProxyManager(child: SizedBox(key: Key('child'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void enableSystemProxy({required bool running, int mixedPort = 7890}) {
    container.read(networkSettingProvider.notifier).value = const NetworkProps()
        .copyWith(systemProxy: true);
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig().copyWith(mixedPort: mixedPort);
    container
        .read(coreRunStateProvider.notifier)
        .observe(
          CoreRunObservation(
            session: 'test',
            revision: ++revision,
            active: running,
            requested: running,
            mixedPort: running ? mixedPort : 0,
          ),
        );
  }

  testWidgets('renders its child unchanged', (tester) async {
    await pumpProxyManager(tester);

    expect(find.byKey(const Key('child')), findsOneWidget);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('platform failures never escape the update chain', (
    tester,
  ) async {
    await pumpProxyManager(tester);

    proxy.success = false;
    enableSystemProxy(running: true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), null);
    expect(
      container.read(systemProxyStateProvider).failure,
      'system_proxy_failed',
    );
    expect(
      container.read(vpnConnectionProvider).phase,
      VpnConnectionPhase.localProxy,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed update does not stall later transitions', (
    tester,
  ) async {
    await pumpProxyManager(tester);

    enableSystemProxy(running: true);
    await tester.pump();
    enableSystemProxy(running: true, mixedPort: 7891);
    await tester.pump();
    enableSystemProxy(running: false);
    await tester.pumpAndSettle();

    expect(container.read(proxyStateProvider).isStart, isFalse);
    expect(tester.takeException(), null);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a running core reports the mixed port as the proxy target', () {
    enableSystemProxy(running: true, mixedPort: 7892);
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig().copyWith(mixedPort: 9999);

    final state = container.read(proxyStateProvider);
    expect(state.isStart, isTrue);
    expect(state.systemProxy, isTrue);
    expect(state.port, 7892);
  });

  testWidgets('successful installation reports proxy-only fallback', (
    tester,
  ) async {
    await pumpProxyManager(tester);
    enableSystemProxy(running: true);
    await tester.pumpAndSettle();
    expect(container.read(systemProxyStateProvider).installed, isTrue);
    expect(
      container.read(vpnConnectionProvider).phase,
      VpnConnectionPhase.proxyOnly,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a late installation converges to a newer stop', (tester) async {
    await pumpProxyManager(tester);
    proxy.startGate = Completer<bool>();
    enableSystemProxy(running: true);
    await tester.pump();
    expect(container.read(systemProxyStateProvider).pending, isTrue);
    enableSystemProxy(running: false);
    await tester.pump();
    proxy.startGate!.complete(true);
    await tester.pumpAndSettle();
    expect(proxy.calls, [0, 7890, 0]);
    expect(container.read(systemProxyStateProvider).installed, isFalse);
    expect(
      container.read(vpnConnectionProvider).phase,
      VpnConnectionPhase.disconnected,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed proxy removal retains observed installation and error', (
    tester,
  ) async {
    await pumpProxyManager(tester);
    enableSystemProxy(running: true);
    await tester.pumpAndSettle();
    proxy.success = false;
    enableSystemProxy(running: false);
    await tester.pumpAndSettle();
    expect(container.read(systemProxyStateProvider).installed, isTrue);
    expect(
      container.read(systemProxyStateProvider).failure,
      'system_proxy_failed',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an installation finishing after disposal is removed', (
    tester,
  ) async {
    await pumpProxyManager(tester);
    proxy.startGate = Completer<bool>();
    enableSystemProxy(running: true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    proxy.startGate!.complete(true);
    await tester.pumpAndSettle();
    expect(proxy.calls, [0, 7890, 0]);
    expect(tester.takeException(), isNull);
  });

  test('an excluded SSID suspends the system proxy', () {
    final suspended = ProviderContainer(
      overrides: [
        excludeSSIDsProvider.overrideWithValue(const ['Office Wi-Fi']),
      ],
    );
    addTearDown(suspended.dispose);
    suspended.read(runTimeProvider.notifier).value = 1;
    suspended.read(currentSSIDProvider.notifier).value = 'Office Wi-Fi';

    expect(suspended.read(proxyStateProvider).isStart, isFalse);
  });
}
