part of '../action.dart';

@Riverpod(keepAlive: true)
class VpnLatency extends _$VpnLatency {
  final _pool = TaskPool(maxConcurrentDelayTests);
  int _revision = 0;
  bool _running = false;

  @override
  VpnLatencyState build() {
    ref.listen(
      currentProfileProvider.select(
        (profile) => (profile?.id, profile?.snapshot.generation),
      ),
      (_, _) => _invalidate(clear: true),
    );
    ref.listen(realTestUrlProvider(null), (_, _) => _invalidate(clear: true));
    ref.listen(coreStatusProvider, (_, next) {
      if (next != CoreStatus.connected) _invalidate(clear: false);
    });
    ref.onDispose(() => _revision++);
    return const VpnLatencyState();
  }

  void _invalidate({required bool clear}) {
    _revision++;
    state = VpnLatencyState(
      running: _running,
      results: clear
          ? const {}
          : Map.unmodifiable({
              for (final entry in state.results.entries)
                entry.key: entry.value.status == VpnLatencyStatus.testing
                    ? const VpnNodeLatency(VpnLatencyStatus.failed)
                    : entry.value,
            }),
    );
  }

  Future<void> testAll() async {
    final profile = ref.read(currentProfileProvider);
    if (_running ||
        profile?.snapshot.generation == null ||
        !ref.read(initProvider) ||
        ref.read(coreStatusProvider) != CoreStatus.connected) {
      return;
    }
    final servers = profile!.snapshot.servers;
    if (servers.isEmpty) return;
    final revision = ++_revision;
    final url = ref.read(realTestUrlProvider(null));
    final core = ref.read(coreHandlerProvider);
    _running = true;
    state = VpnLatencyState(
      running: true,
      results: Map.unmodifiable({
        for (final server in servers)
          server.id: const VpnNodeLatency(VpnLatencyStatus.testing),
      }),
    );
    bool current() {
      if (!ref.mounted || revision != _revision) return false;
      final latest = ref.read(currentProfileProvider);
      if (latest?.id != profile.id ||
          latest?.snapshot.generation != profile.snapshot.generation ||
          ref.read(realTestUrlProvider(null)) != url) {
        _invalidate(clear: true);
        return false;
      }
      if (ref.read(coreStatusProvider) != CoreStatus.connected) {
        _invalidate(clear: false);
        return false;
      }
      return true;
    }

    try {
      await Future.wait(
        servers.map(
          (server) => _pool.run(() async {
            if (!current()) return;
            VpnNodeLatency result;
            try {
              final delay = await core
                  .getDelay(url, server.target)
                  .timeout(delayTestGuardDuration);
              result =
                  delay != null &&
                      (delay.name != server.target || delay.url != url)
                  ? const VpnNodeLatency(VpnLatencyStatus.failed)
                  : VpnNodeLatency.fromDelay(delay);
            } catch (_) {
              result = const VpnNodeLatency(VpnLatencyStatus.failed);
            }
            if (!current()) return;
            state = VpnLatencyState(
              running: true,
              results: Map.unmodifiable({...state.results, server.id: result}),
            );
          }),
        ),
      );
    } finally {
      _running = false;
      if (ref.mounted) {
        state = VpnLatencyState(results: state.results);
      }
    }
  }
}
