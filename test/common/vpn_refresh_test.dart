import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late Profile profile;
  late VpnRefreshScheduler scheduler;
  late List<Set<String>?> calls;
  late Future<VpnImportResult> Function(void Function()) run;

  setUp(() {
    now = DateTime.utc(2026);
    profile = Profile(
      id: 1,
      url: 'https://example.test/subscription',
      autoUpdateDuration: const Duration(hours: 1),
      lastUpdateDate: now,
      snapshot: ProfileSnapshot(
        generation: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        revision: 1,
        providerRefresh: [
          VpnProviderRefresh(
            section: 'proxy-providers',
            name: 'fast',
            interval: 60,
            lastUpdate: now,
          ),
          VpnProviderRefresh(
            section: 'rule-providers',
            name: 'slow',
            interval: 300,
            lastUpdate: now,
          ),
        ],
      ),
    );
    calls = [];
    run = (check) async {
      check();
      final resources = calls.last;
      profile = profile.copyWith(
        lastUpdateDate: resources == null ? now : profile.lastUpdateDate,
        snapshot: profile.snapshot.copyWith(
          providerRefresh: [
            for (final provider in profile.snapshot.providerRefresh)
              resources == null || resources.contains(provider.key)
                  ? provider.copyWith(lastUpdate: now)
                  : provider,
          ],
        ),
      );
      return VpnImportResult(VpnImportOutcome.success, profile: profile);
    };
    scheduler = VpnRefreshScheduler(
      current: () => profile,
      now: () => now,
      refresh: (_, resources, check) {
        calls.add(resources);
        return run(check);
      },
    );
  });

  tearDown(() => scheduler.dispose());

  Future<void> advance(WidgetTester tester, Duration duration) async {
    now = now.add(duration);
    await tester.pump(duration);
  }

  testWidgets('closed app stays idle and refreshes due providers on return', (
    tester,
  ) async {
    await advance(tester, const Duration(minutes: 10));
    expect(calls, isEmpty);
    scheduler.setActive(true);
    await tester.pump(Duration.zero);
    expect(calls, [
      {'proxy-providers/fast', 'rule-providers/slow'},
    ]);
    scheduler.setActive(false);
    await advance(tester, const Duration(hours: 2));
    expect(calls, hasLength(1));
    scheduler.setActive(true);
    await tester.pump(Duration.zero);
    expect(calls, hasLength(2));
    expect(calls.last, isNull);
    scheduler.dispose();
  });

  testWidgets('each provider retains its own configured interval', (
    tester,
  ) async {
    scheduler.setActive(true);
    await advance(tester, const Duration(minutes: 1));
    expect(calls, [
      {'proxy-providers/fast'},
    ]);
    await advance(tester, const Duration(minutes: 4));
    expect(calls.last, {'proxy-providers/fast', 'rule-providers/slow'});
    expect(profile.lastUpdateDate, DateTime.utc(2026));
    scheduler.dispose();
  });

  testWidgets(
    'failed refresh is throttled without changing the last good snapshot',
    (tester) async {
      final original = profile;
      run = (_) async => const VpnImportResult(VpnImportOutcome.failed);
      scheduler.setActive(true);
      await advance(tester, const Duration(minutes: 1));
      expect(calls, hasLength(1));
      await advance(tester, const Duration(seconds: 59));
      expect(calls, hasLength(1));
      await advance(tester, const Duration(seconds: 1));
      expect(calls, hasLength(2));
      expect(profile, original);
      scheduler.dispose();
    },
  );

  testWidgets('detaching invalidates an in-flight automatic refresh', (
    tester,
  ) async {
    final gate = Completer<void>();
    var rejected = false;
    run = (check) async {
      await gate.future;
      try {
        check();
      } on VpnImportCancelled {
        rejected = true;
        return const VpnImportResult(VpnImportOutcome.cancelled);
      }
      return const VpnImportResult(VpnImportOutcome.success);
    };
    scheduler.setActive(true);
    await advance(tester, const Duration(minutes: 1));
    scheduler.setActive(false);
    gate.complete();
    await tester.pump();
    expect(rejected, isTrue);
    await advance(tester, const Duration(hours: 1));
    expect(calls, hasLength(1));
  });

  testWidgets('file profiles still refresh their remote providers', (
    tester,
  ) async {
    profile = profile.copyWith(url: '', autoUpdate: false);
    scheduler.setActive(true);
    await advance(tester, const Duration(minutes: 1));
    expect(calls.single, {'proxy-providers/fast'});
    scheduler.dispose();
    await advance(tester, const Duration(hours: 1));
    expect(calls, hasLength(1));
  });
}
