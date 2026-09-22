import 'package:fl_clash/common/vpn_connection.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const core = CoreRunObservation(
    session: 'desktop',
    revision: 1,
    active: true,
    requested: true,
    mixedPort: 7890,
  );
  const native = AndroidRunObservation(
    session: 'android',
    revision: 1,
    state: VpnRunState.started,
    startedAt: 100,
    vpn: true,
  );

  VpnConnection derive({
    bool android = false,
    bool ready = true,
    bool suspended = false,
    CoreRunObservation? observed,
    AndroidRunObservation? service,
    SystemProxyObservation proxy = const SystemProxyObservation(),
    bool? pending,
    String? failure,
    bool requested = false,
  }) => deriveVpnConnection(
    android: android,
    coreReady: ready,
    suspended: suspended,
    systemProxyRequested: true,
    core: observed,
    native: service,
    proxy: proxy,
    pending: pending,
    failure: failure,
    runRequested: requested,
  );

  test('Core-ready without listeners is disconnected', () {
    expect(derive().phase, VpnConnectionPhase.disconnected);
    expect(
      derive(observed: core.copyWith(active: false)).phase,
      VpnConnectionPhase.disconnected,
    );
  });

  test(
    'Android attachment waits for native evidence instead of showing off',
    () {
      expect(derive(android: true).phase, VpnConnectionPhase.checking);
      expect(
        derive(android: true, pending: true).phase,
        VpnConnectionPhase.connecting,
      );
      expect(
        derive(android: true, failure: 'core_unavailable').phase,
        VpnConnectionPhase.failed,
      );
    },
  );

  test(
    'failed teardown is retryable without inventing stopped or connected',
    () {
      for (final startedAt in [0, 100]) {
        final result = derive(
          android: true,
          service: native.copyWith(
            state: VpnRunState.stopping,
            failure: 'stop_failed',
            requested: false,
            startedAt: startedAt,
          ),
        );
        expect(result.phase, VpnConnectionPhase.failed);
        expect(result.canDisconnect, isTrue);
      }
    },
  );

  test('only an observed TUN is connected', () {
    expect(
      derive(observed: core.copyWith(tun: true)).phase,
      VpnConnectionPhase.connected,
    );
    expect(
      derive(observed: core, ready: false).phase,
      VpnConnectionPhase.disconnected,
    );
  });

  test('working system proxy is labelled proxy-only, not VPN', () {
    expect(
      derive(
        observed: core,
        proxy: const SystemProxyObservation(installed: true, port: 7890),
      ).phase,
      VpnConnectionPhase.proxyOnly,
    );
    expect(
      derive(
        observed: core,
        proxy: const SystemProxyObservation(installed: true, port: 7891),
      ).phase,
      VpnConnectionPhase.localProxy,
    );
  });

  test(
    'proxy failure remains visible with a local listener or working TUN',
    () {
      const failure = SystemProxyObservation(failure: 'system_proxy_failed');
      final local = derive(observed: core, proxy: failure);
      expect(local.phase, VpnConnectionPhase.localProxy);
      expect(local.failure, 'system_proxy_failed');
      expect(local.canDisconnect, isTrue);
      final tun = derive(observed: core.copyWith(tun: true), proxy: failure);
      expect(tun.phase, VpnConnectionPhase.connected);
      expect(tun.failure, 'system_proxy_failed');
    },
  );

  test('pending proxy installation waits for a result', () {
    expect(
      derive(
        observed: core,
        proxy: const SystemProxyObservation(pending: true),
      ).phase,
      VpnConnectionPhase.connecting,
    );
  });

  test('Android permission wait is cancellable but never connected', () {
    final state = derive(
      android: true,
      service: native.copyWith(state: VpnRunState.starting, startedAt: 0),
    );
    expect(state.phase, VpnConnectionPhase.connecting);
    expect(state.canDisconnect, isTrue);
    expect(
      derive(android: true, service: native).phase,
      VpnConnectionPhase.connected,
    );
    expect(
      derive(android: true, service: native.copyWith(vpn: false)).phase,
      VpnConnectionPhase.localProxy,
    );
  });

  test(
    'permission denial and revoke are reflected without optimistic intent',
    () {
      final denied = derive(
        android: true,
        service: native.copyWith(
          state: VpnRunState.stopped,
          startedAt: 0,
          failure: 'vpn_permission_denied',
        ),
      );
      expect(denied.phase, VpnConnectionPhase.failed);
      expect(denied.canDisconnect, isFalse);
      expect(
        derive(
          android: true,
          service: native.copyWith(state: VpnRunState.stopped, startedAt: 0),
        ).phase,
        VpnConnectionPhase.disconnected,
      );
    },
  );

  test('stop intent takes precedence over late starting observations', () {
    expect(
      derive(
        android: true,
        pending: false,
        service: native.copyWith(state: VpnRunState.starting),
      ).phase,
      VpnConnectionPhase.disconnecting,
    );
  });

  test('suspended intent is visible even while listeners are stopped', () {
    final result = derive(suspended: true, requested: true);
    expect(result.phase, VpnConnectionPhase.suspended);
    expect(result.canDisconnect, isTrue);
  });

  test('failed recovery never invents a connection', () {
    final result = derive(failure: 'recovery_failed');
    expect(result.phase, VpnConnectionPhase.failed);
    expect(result.failure, 'recovery_failed');
  });

  test('session cursor ignores stale revisions and retired sessions', () {
    final cursor = RunObservationCursor();
    expect(cursor.accept('a', 2), isTrue);
    expect(cursor.accept('a', 1), isFalse);
    expect(cursor.accept('a', 2), isFalse);
    expect(cursor.accept('b', 0), isTrue);
    expect(cursor.accept('a', 999), isFalse);
    expect(cursor.accept('b', 1), isTrue);
  });
}
