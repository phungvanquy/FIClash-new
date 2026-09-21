import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'vpn_coordinator.dart';

class VpnRefreshScheduler {
  VpnRefreshScheduler({
    required this.current,
    required this.refresh,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final Profile? Function() current;
  final Future<VpnImportResult> Function(
    Profile profile,
    Set<String>? providers,
    void Function() checkCurrent,
  )
  refresh;
  final DateTime Function() now;
  Timer? _timer;
  bool _active = false;
  bool _busy = false;
  bool _disposed = false;
  int _epoch = 0;
  DateTime? _retryAfter;

  void setActive(bool active) {
    if (_disposed) return;
    if (_active != active) _epoch++;
    _active = active;
    reschedule();
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
  }

  DateTime? _subscriptionDue(Profile profile) =>
      profile.autoUpdate &&
          profile.type == ProfileType.url &&
          profile.autoUpdateDuration > Duration.zero
      ? profile.lastUpdateDate?.add(profile.autoUpdateDuration) ?? now()
      : null;

  void reschedule() {
    _timer?.cancel();
    if (!_active || _disposed || _busy) return;
    final profile = current();
    if (profile?.snapshot.generation == null) return;
    final dates = [
      ?_subscriptionDue(profile!),
      for (final provider in profile.snapshot.providerRefresh)
        if (provider.interval > 0)
          provider.lastUpdate?.add(Duration(seconds: provider.interval)) ??
              now(),
    ];
    if (dates.isEmpty) return;
    var due = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final retryAfter = _retryAfter;
    if (retryAfter != null && due.isBefore(retryAfter)) due = retryAfter;
    final delay = due.difference(now());
    _timer = Timer(delay.isNegative ? Duration.zero : delay, _run);
  }

  Future<void> _run() async {
    if (!_active || _disposed || _busy) return;
    final profile = current();
    if (profile?.snapshot.generation == null) return;
    final epoch = _epoch;
    final date = now();
    final subscription = _subscriptionDue(profile!);
    final all = subscription != null && !subscription.isAfter(date);
    final providers = <String>{
      for (final provider in profile.snapshot.providerRefresh)
        if (provider.interval > 0 &&
            !(provider.lastUpdate?.add(Duration(seconds: provider.interval)) ??
                    date)
                .isAfter(date))
          provider.key,
    };
    if (!all && providers.isEmpty) {
      reschedule();
      return;
    }
    _busy = true;
    try {
      final result = await refresh(profile, all ? null : providers, () {
        if (_disposed || !_active || _epoch != epoch) {
          throw const VpnImportCancelled();
        }
      });
      _retryAfter = result.outcome == VpnImportOutcome.success
          ? null
          : now().add(const Duration(minutes: 1));
    } catch (_) {
      _retryAfter = now().add(const Duration(minutes: 1));
    } finally {
      _busy = false;
      reschedule();
    }
  }
}
