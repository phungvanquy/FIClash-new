import 'package:fl_clash/models/models.dart';

class RunObservationCursor {
  String? _session;
  int _revision = -1;
  final _retired = <String>{};

  bool accept(String session, int revision) {
    if (_retired.contains(session)) return false;
    if (_session == session && revision <= _revision) return false;
    if (_session != null && _session != session) _retired.add(_session!);
    _session = session;
    _revision = revision;
    return true;
  }
}

VpnConnection deriveVpnConnection({
  required bool android,
  required bool coreReady,
  required bool suspended,
  required bool systemProxyRequested,
  CoreRunObservation? core,
  AndroidRunObservation? native,
  SystemProxyObservation proxy = const SystemProxyObservation(),
  bool? pending,
  String? failure,
  bool runRequested = false,
}) {
  final active = android
      ? native?.state == VpnRunState.started
      : coreReady && core?.active == true;
  final requested = android
      ? native?.state == VpnRunState.starting || active
      : core?.requested == true;
  final canDisconnect = active || requested || runRequested || pending == true;
  final issue =
      failure ?? (android ? native?.failure : core?.failure ?? proxy.failure);
  if (issue == 'recovery_required') {
    return VpnConnection(
      phase: VpnConnectionPhase.failed,
      canDisconnect: canDisconnect,
      failure: issue,
    );
  }
  if (pending == false || (android && native?.state == VpnRunState.stopping)) {
    return VpnConnection(
      phase: VpnConnectionPhase.disconnecting,
      canDisconnect: true,
      failure: issue,
    );
  }
  if ((suspended || (!android && core?.suspended == true)) && canDisconnect) {
    return VpnConnection(
      phase: VpnConnectionPhase.suspended,
      canDisconnect: true,
      failure: issue,
    );
  }
  if (pending == true || (android && native?.state == VpnRunState.starting)) {
    return VpnConnection(
      phase: VpnConnectionPhase.connecting,
      canDisconnect: true,
      failure: issue,
    );
  }
  if (active) {
    if (android ? native!.vpn : core!.tun) {
      return VpnConnection(
        phase: VpnConnectionPhase.connected,
        canDisconnect: true,
        failure: issue ?? proxy.failure,
      );
    }
    if (!android && proxy.installed && proxy.port == core!.mixedPort) {
      return VpnConnection(
        phase: VpnConnectionPhase.proxyOnly,
        canDisconnect: true,
        failure: issue ?? proxy.failure,
      );
    }
    if (!android && systemProxyRequested && proxy.pending) {
      return const VpnConnection(
        phase: VpnConnectionPhase.connecting,
        canDisconnect: true,
      );
    }
    return VpnConnection(
      phase: VpnConnectionPhase.localProxy,
      canDisconnect: true,
      failure: issue ?? proxy.failure,
    );
  }
  return VpnConnection(
    phase: issue == null
        ? VpnConnectionPhase.disconnected
        : VpnConnectionPhase.failed,
    canDisconnect: canDisconnect,
    failure: issue,
  );
}
