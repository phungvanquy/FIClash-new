import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

Profile _profile({int count = 3, String generation = 'first'}) => Profile(
  id: 1,
  autoUpdateDuration: Duration.zero,
  snapshot: ProfileSnapshot(
    generation: generation,
    selection: const VpnSelection.server('node-1'),
    servers: List.generate(
      count,
      (index) => VpnServer(
        id: 'node-$index',
        name: 'Duplicate display name',
        target: 'unique-$index',
        type: 'Vless',
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Core core;

  void create({int count = 3}) {
    core = _Core();
    final profile = _profile(count: count);
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
      ],
    );
    container.read(initProvider.notifier).value = true;
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    container.read(appSettingProvider.notifier).value = const AppSettingProps(
      testUrl: 'https://probe.test',
    );
    addTearDown(container.dispose);
    container.listen(vpnLatencyProvider, (_, _) {});
  }

  VpnLatency action() => container.read(vpnLatencyProvider.notifier);
  VpnLatencyState state() => container.read(vpnLatencyProvider);

  test(
    'measures unique targets and highlights fastest without changing VPN',
    () async {
      create();
      final profile = container.read(currentProfileProvider);
      container.read(vpnRunRequestedProvider.notifier).value = true;
      when(() => core.asyncTestDelay(any(), any())).thenAnswer((call) async {
        final target = call.positionalArguments[1] as String;
        return Delay(
          name: target,
          url: call.positionalArguments[0] as String,
          value: {'unique-0': 900, 'unique-1': 15, 'unique-2': 120}[target],
        );
      });
      await action().testAll();
      expect(state().fastestId, 'node-1');
      expect(state().results['node-0']!.milliseconds, 900);
      expect(state().running, isFalse);
      expect(container.read(currentProfileProvider), profile);
      expect(container.read(vpnRunRequestedProvider), isTrue);
      verify(() => core.asyncTestDelay('https://probe.test', any())).called(3);
      verifyNoMoreInteractions(core);
    },
  );

  test(
    'distinguishes probe timeout, unreachable and channel failure',
    () async {
      create();
      when(() => core.asyncTestDelay(any(), any())).thenAnswer((call) async {
        final target = call.positionalArguments[1] as String;
        if (target == 'unique-2') return null;
        return Delay(
          name: target,
          url: 'https://probe.test',
          value: -1,
          failure: target == 'unique-0' ? 'timeout' : 'unreachable',
        );
      });
      await action().testAll();
      expect(state().results['node-0']!.status, VpnLatencyStatus.timeout);
      expect(state().results['node-1']!.status, VpnLatencyStatus.unreachable);
      expect(state().results['node-2']!.status, VpnLatencyStatus.failed);
      expect(state().fastestId, isNull);
      expect(container.read(vpnRunRequestedProvider), isFalse);
      expect(state().running, isFalse);
    },
  );

  test('exceptions and malformed replies finish and permit retry', () async {
    create(count: 1);
    when(
      () => core.asyncTestDelay(any(), any()),
    ).thenThrow(StateError('offline'));
    await action().testAll();
    expect(state().results['node-0']!.status, VpnLatencyStatus.failed);
    expect(state().running, isFalse);
    when(() => core.asyncTestDelay(any(), any())).thenAnswer(
      (_) async =>
          const Delay(name: 'wrong', url: 'https://probe.test', value: 1),
    );
    await action().testAll();
    expect(state().results['node-0']!.status, VpnLatencyStatus.failed);
  });

  test('one batch at a time with bounded concurrency', () async {
    create(count: maxConcurrentDelayTests + 3);
    final gate = Completer<void>();
    var calls = 0;
    when(() => core.asyncTestDelay(any(), any())).thenAnswer((call) async {
      calls++;
      await gate.future;
      return Delay(
        name: call.positionalArguments[1] as String,
        url: 'https://probe.test',
        value: 20,
      );
    });
    final run = action().testAll();
    await action().testAll();
    expect(calls, maxConcurrentDelayTests);
    expect(state().running, isTrue);
    gate.complete();
    await run;
    expect(calls, maxConcurrentDelayTests + 3);
    expect(state().running, isFalse);
  });

  for (final invalidation in ['profile', 'url', 'core', 'dispose']) {
    test('ignores late results after $invalidation changes', () async {
      create(count: maxConcurrentDelayTests + 1);
      final gate = Completer<Delay?>();
      var calls = 0;
      when(() => core.asyncTestDelay(any(), any())).thenAnswer((_) {
        calls++;
        return gate.future;
      });
      final run = action().testAll();
      switch (invalidation) {
        case 'profile':
          (container.read(profilesProvider.notifier) as TestProfiles).replace([
            _profile(generation: 'replacement'),
          ]);
        case 'url':
          container.read(appSettingProvider.notifier).value =
              const AppSettingProps(testUrl: 'https://different.test');
        case 'core':
          container.read(coreStatusProvider.notifier).value =
              CoreStatus.disconnected;
        case 'dispose':
          container.dispose();
      }
      if (invalidation != 'dispose') await container.pump();
      gate.complete(
        const Delay(name: 'unique-0', url: 'https://probe.test', value: 1),
      );
      await run;
      expect(calls, maxConcurrentDelayTests);
      if (invalidation == 'dispose') return;
      expect(state().running, isFalse);
      expect(state().fastestId, isNull);
      if (invalidation == 'core') {
        expect(
          state().results.values.every(
            (item) => item.status == VpnLatencyStatus.failed,
          ),
          isTrue,
        );
      } else {
        expect(state().results, isEmpty);
      }
    });
  }

  test('unavailable Core cannot start a batch', () async {
    create();
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await action().testAll();
    expect(state().results, isEmpty);
    verifyZeroInteractions(core);
  });
}
