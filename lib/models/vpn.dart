import 'package:fl_clash/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'core.dart';

part 'generated/vpn.freezed.dart';
part 'generated/vpn.g.dart';

enum VpnRoutingMode { simple, custom }

enum VpnConnectionPhase {
  disconnected,
  connecting,
  connected,
  disconnecting,
  proxyOnly,
  localProxy,
  suspended,
  failed,
}

@freezed
abstract class CoreRunObservation with _$CoreRunObservation {
  const factory CoreRunObservation({
    required String session,
    required int revision,
    @Default(false) bool requested,
    @Default(false) bool active,
    @Default(false) bool suspended,
    @Default(false) bool tun,
    @Default(0) int mixedPort,
    String? generation,
    int? configRevision,
    String? failure,
  }) = _CoreRunObservation;

  factory CoreRunObservation.fromJson(Map<String, Object?> json) =>
      _$CoreRunObservationFromJson(json);
}

@freezed
abstract class VpnConnection with _$VpnConnection {
  const factory VpnConnection({
    @Default(VpnConnectionPhase.disconnected) VpnConnectionPhase phase,
    @Default(false) bool canDisconnect,
    String? failure,
  }) = _VpnConnection;
}

@freezed
abstract class SystemProxyObservation with _$SystemProxyObservation {
  const factory SystemProxyObservation({
    @Default(false) bool pending,
    @Default(false) bool installed,
    @Default(0) int port,
    String? failure,
  }) = _SystemProxyObservation;
}

enum VpnRunState {
  @JsonValue('STOPPED')
  stopped,
  @JsonValue('STARTING')
  starting,
  @JsonValue('STARTED')
  started,
  @JsonValue('STOPPING')
  stopping,
}

@freezed
abstract class AndroidRunObservation with _$AndroidRunObservation {
  const factory AndroidRunObservation({
    required String session,
    required int revision,
    required VpnRunState state,
    @Default(0) int startedAt,
    @Default(false) bool vpn,
    String? failure,
  }) = _AndroidRunObservation;

  factory AndroidRunObservation.fromJson(Map<String, Object?> json) =>
      _$AndroidRunObservationFromJson(json);
}

@freezed
abstract class PrepareConfigParams with _$PrepareConfigParams {
  const factory PrepareConfigParams({
    required String generation,
    required int revision,
    @JsonKey(includeIfNull: false) bool? probe,
  }) = _PrepareConfigParams;

  factory PrepareConfigParams.fromJson(Map<String, Object?> json) =>
      _$PrepareConfigParamsFromJson(json);
}

@freezed
abstract class PreparedConfigResult with _$PreparedConfigResult {
  @JsonSerializable(explicitToJson: true)
  const factory PreparedConfigResult({
    required String handle,
    required String generation,
    required int revision,
    required List<VpnServer> servers,
  }) = _PreparedConfigResult;

  factory PreparedConfigResult.fromJson(Map<String, Object?> json) =>
      _$PreparedConfigResultFromJson(json);
}

@freezed
abstract class PreparedConfigRef with _$PreparedConfigRef {
  const factory PreparedConfigRef({
    required String handle,
    required int revision,
  }) = _PreparedConfigRef;

  factory PreparedConfigRef.fromJson(Map<String, Object?> json) =>
      _$PreparedConfigRefFromJson(json);
}

@freezed
abstract class ActivateConfigParams with _$ActivateConfigParams {
  @JsonSerializable(explicitToJson: true)
  const factory ActivateConfigParams({
    required PreparedConfigRef prepared,
    required SetupParams setup,
  }) = _ActivateConfigParams;

  factory ActivateConfigParams.fromJson(Map<String, Object?> json) =>
      _$ActivateConfigParamsFromJson(json);
}

@freezed
abstract class ActivatedConfigResult with _$ActivatedConfigResult {
  const factory ActivatedConfigResult({
    required String generation,
    required int revision,
  }) = _ActivatedConfigResult;

  factory ActivatedConfigResult.fromJson(Map<String, Object?> json) =>
      _$ActivatedConfigResultFromJson(json);
}

@Freezed(unionKey: 'kind')
sealed class VpnSelection with _$VpnSelection {
  const factory VpnSelection.auto() = VpnAutoSelection;

  const factory VpnSelection.fallback() = VpnFallbackSelection;

  const factory VpnSelection.server(String id) = VpnServerSelection;

  factory VpnSelection.fromJson(Map<String, Object?> json) =>
      _$VpnSelectionFromJson(json);
}

@freezed
abstract class VpnServer with _$VpnServer {
  const factory VpnServer({
    required String id,
    required String name,
    required String target,
    required String type,
    String? provider,
  }) = _VpnServer;

  factory VpnServer.fromJson(Map<String, Object?> json) =>
      _$VpnServerFromJson(json);
}

@freezed
abstract class ProfileSnapshot with _$ProfileSnapshot {
  const factory ProfileSnapshot({
    @Default(0) int revision,
    String? generation,
    @Default(VpnRoutingMode.simple) VpnRoutingMode routing,
    @Default(VpnSelection.auto()) VpnSelection selection,
    @Default(Mode.rule) Mode advancedMode,
    @Default([]) List<VpnServer> servers,
    @Default([]) List<VpnProviderRefresh> providerRefresh,
    VpnManagedGroups? managedGroups,
  }) = _ProfileSnapshot;

  factory ProfileSnapshot.fromJson(Map<String, Object?> json) =>
      _$ProfileSnapshotFromJson(json);
}

@freezed
abstract class VpnProviderRefresh with _$VpnProviderRefresh {
  const factory VpnProviderRefresh({
    required String section,
    required String name,
    required int interval,
    DateTime? lastUpdate,
  }) = _VpnProviderRefresh;

  factory VpnProviderRefresh.fromJson(Map<String, Object?> json) =>
      _$VpnProviderRefreshFromJson(json);
}

extension VpnProviderRefreshKey on VpnProviderRefresh {
  String get key => '$section/$name';
}

@freezed
abstract class VpnManagedGroups with _$VpnManagedGroups {
  const factory VpnManagedGroups({
    required String selector,
    required String auto,
    required String fallback,
  }) = _VpnManagedGroups;

  factory VpnManagedGroups.fromJson(Map<String, Object?> json) =>
      _$VpnManagedGroupsFromJson(json);
}
