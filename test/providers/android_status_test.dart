import 'dart:async';

import 'package:fl_clash/common/vpn_connection.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Service extends Mock implements Service {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Service service;
  const stopped = AndroidRunObservation(
    session: 'android',
    revision: 0,
    state: VpnRunState.stopped,
  );

  setUp(() {
    service = _Service();
    container = ProviderContainer(
      overrides: [
        androidServiceProvider.overrideWithValue(service),
        profilesProvider.overrideWith(TestProfiles.new),
      ],
    );
  });
  tearDown(() => container.dispose());

  VpnConnection connection() => deriveVpnConnection(
    android: true,
    coreReady: true,
    suspended: false,
    systemProxyRequested: false,
    native: container.read(androidRunStateProvider),
    failure: container.read(vpnFailureProvider),
  );

  test(
    'initial native STOPPED unlocks the imported profile without starting VPN',
    () async {
      expect(connection().phase, VpnConnectionPhase.checking);
      when(service.getRunState).thenAnswer((_) async => stopped);
      await container.read(setupActionProvider.notifier).syncRunState();
      expect(connection().phase, VpnConnectionPhase.disconnected);
      expect(container.read(vpnRunRequestedProvider), isFalse);
      verify(service.getRunState).called(1);
      verifyNoMoreInteractions(service);
    },
  );

  for (final response in ['null', 'malformed', 'channel']) {
    test(
      '$response snapshot gives safe disconnect and successful retry',
      () async {
        when(service.getRunState).thenAnswer((_) async {
          if (response == 'malformed') throw const FormatException();
          if (response == 'channel') throw StateError('channel closed');
          return null;
        });
        final action = container.read(setupActionProvider.notifier);
        await action.syncRunState();
        expect(connection().phase, VpnConnectionPhase.failed);
        expect(connection().failure, 'state_unavailable');
        expect(connection().canDisconnect, isTrue);
        expect(container.read(androidRunStateProvider), isNull);
        when(service.getRunState).thenAnswer((_) async => stopped);
        await action.syncRunState();
        expect(connection().phase, VpnConnectionPhase.disconnected);
        expect(container.read(vpnFailureProvider), isNull);
      },
    );
  }

  testWidgets('status timeout is bounded and duplicate checks coalesce', (
    tester,
  ) async {
    final gate = Completer<AndroidRunObservation?>();
    when(service.getRunState).thenAnswer((_) => gate.future);
    final action = container.read(setupActionProvider.notifier);
    final first = action.syncRunState();
    expect(action.syncRunState(), same(first));
    await tester.pump(const Duration(seconds: 5));
    await first;
    expect(connection().failure, 'state_unavailable');
    verify(service.getRunState).called(1);
    gate.complete(stopped);
    await tester.pump();
    expect(connection().failure, 'state_unavailable');
    when(service.getRunState).thenAnswer((_) async => stopped);
    await action.syncRunState();
    expect(connection().phase, VpnConnectionPhase.disconnected);
    container.dispose();
    await tester.pump();
  });

  test('late failed query cannot replace a newer native observation', () async {
    final gate = Completer<AndroidRunObservation?>();
    when(service.getRunState).thenAnswer((_) => gate.future);
    final action = container.read(setupActionProvider.notifier);
    final pending = action.syncRunState();
    action.observeAndroid(stopped.copyWith(revision: 1));
    gate.completeError(StateError('late error'));
    await pending;
    expect(connection().phase, VpnConnectionPhase.disconnected);
  });

  test(
    'fresh identical snapshot clears status error but preserves stop failure',
    () async {
      final action = container.read(setupActionProvider.notifier);
      action.observeAndroid(stopped.copyWith(state: VpnRunState.started));
      final latest = container.read(androidRunStateProvider);
      when(service.getRunState).thenAnswer((_) async => latest);
      container.read(vpnFailureProvider.notifier).value = 'state_unavailable';
      await action.syncRunState();
      expect(container.read(vpnFailureProvider), isNull);
      container.read(vpnFailureProvider.notifier).value = 'stop_failed';
      await action.syncRunState();
      expect(container.read(vpnFailureProvider), 'stop_failed');
    },
  );

  test('disposing during snapshot does not publish', () async {
    final gate = Completer<AndroidRunObservation?>();
    when(service.getRunState).thenAnswer((_) => gate.future);
    final pending = container.read(setupActionProvider.notifier).syncRunState();
    container.dispose();
    gate.complete(stopped);
    await pending;
  });
}
