part of '../action.dart';

@riverpod
class VpnActiveNode extends _$VpnActiveNode {
  @override
  AsyncValue<VpnServer?> build() {
    final profile = ref.watch(currentProfileProvider);
    final phase = ref.watch(
      vpnConnectionProvider.select((value) => value.phase),
    );
    final coreReady = ref.watch(coreStatusProvider) == CoreStatus.connected;
    final home = ref.watch(currentPageLabelProvider) == PageLabel.dashboard;
    if (phase != VpnConnectionPhase.connected ||
        !home ||
        !coreReady ||
        profile?.snapshot.generation == null ||
        profile!.snapshot.routing != VpnRoutingMode.simple) {
      return const AsyncData(null);
    }
    final core = ref.read(coreHandlerProvider);
    Timer? poll;
    Timer? guard;
    var disposed = false;
    var reading = false;
    var epoch = 0;
    var foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    Future<void> refresh() async {
      if (disposed || !foreground || reading) return;
      reading = true;
      final request = epoch;
      var expired = false;
      bool current() => !disposed && foreground && request == epoch;
      guard = Timer(const Duration(seconds: 5), () {
        expired = true;
        if (current()) state = const AsyncData(null);
      });
      try {
        final server = await core.getActiveVpnServer(profile.snapshot);
        if (current() && !expired) state = AsyncData(server);
      } catch (_) {
        if (current()) state = const AsyncData(null);
      } finally {
        guard?.cancel();
        reading = false;
        if (!disposed && foreground) {
          poll = Timer(const Duration(seconds: 5), refresh);
        }
      }
    }

    final lifecycle = AppLifecycleListener(
      onStateChange: (next) {
        foreground = next == AppLifecycleState.resumed;
        epoch++;
        poll?.cancel();
        guard?.cancel();
        state = const AsyncData(null);
        if (foreground) unawaited(refresh());
      },
    );
    ref.onDispose(() {
      disposed = true;
      poll?.cancel();
      guard?.cancel();
      lifecycle.dispose();
    });
    Future.microtask(refresh);
    return const AsyncLoading();
  }
}
