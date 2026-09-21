// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../vpn.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CoreRunObservation _$CoreRunObservationFromJson(Map<String, dynamic> json) =>
    _CoreRunObservation(
      session: json['session'] as String,
      revision: (json['revision'] as num).toInt(),
      requested: json['requested'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      suspended: json['suspended'] as bool? ?? false,
      tun: json['tun'] as bool? ?? false,
      mixedPort: (json['mixedPort'] as num?)?.toInt() ?? 0,
      generation: json['generation'] as String?,
      configRevision: (json['configRevision'] as num?)?.toInt(),
      failure: json['failure'] as String?,
    );

Map<String, dynamic> _$CoreRunObservationToJson(_CoreRunObservation instance) =>
    <String, dynamic>{
      'session': instance.session,
      'revision': instance.revision,
      'requested': instance.requested,
      'active': instance.active,
      'suspended': instance.suspended,
      'tun': instance.tun,
      'mixedPort': instance.mixedPort,
      'generation': instance.generation,
      'configRevision': instance.configRevision,
      'failure': instance.failure,
    };

_AndroidRunObservation _$AndroidRunObservationFromJson(
  Map<String, dynamic> json,
) => _AndroidRunObservation(
  session: json['session'] as String,
  revision: (json['revision'] as num).toInt(),
  state: $enumDecode(_$VpnRunStateEnumMap, json['state']),
  startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
  vpn: json['vpn'] as bool? ?? false,
  failure: json['failure'] as String?,
);

Map<String, dynamic> _$AndroidRunObservationToJson(
  _AndroidRunObservation instance,
) => <String, dynamic>{
  'session': instance.session,
  'revision': instance.revision,
  'state': _$VpnRunStateEnumMap[instance.state]!,
  'startedAt': instance.startedAt,
  'vpn': instance.vpn,
  'failure': instance.failure,
};

const _$VpnRunStateEnumMap = {
  VpnRunState.stopped: 'STOPPED',
  VpnRunState.starting: 'STARTING',
  VpnRunState.started: 'STARTED',
  VpnRunState.stopping: 'STOPPING',
};

_PrepareConfigParams _$PrepareConfigParamsFromJson(Map<String, dynamic> json) =>
    _PrepareConfigParams(
      generation: json['generation'] as String,
      revision: (json['revision'] as num).toInt(),
      probe: json['probe'] as bool?,
    );

Map<String, dynamic> _$PrepareConfigParamsToJson(
  _PrepareConfigParams instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'revision': instance.revision,
  'probe': ?instance.probe,
};

_PreparedConfigResult _$PreparedConfigResultFromJson(
  Map<String, dynamic> json,
) => _PreparedConfigResult(
  handle: json['handle'] as String,
  generation: json['generation'] as String,
  revision: (json['revision'] as num).toInt(),
  servers: (json['servers'] as List<dynamic>)
      .map((e) => VpnServer.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PreparedConfigResultToJson(
  _PreparedConfigResult instance,
) => <String, dynamic>{
  'handle': instance.handle,
  'generation': instance.generation,
  'revision': instance.revision,
  'servers': instance.servers.map((e) => e.toJson()).toList(),
};

_PreparedConfigRef _$PreparedConfigRefFromJson(Map<String, dynamic> json) =>
    _PreparedConfigRef(
      handle: json['handle'] as String,
      revision: (json['revision'] as num).toInt(),
    );

Map<String, dynamic> _$PreparedConfigRefToJson(_PreparedConfigRef instance) =>
    <String, dynamic>{'handle': instance.handle, 'revision': instance.revision};

_ActivateConfigParams _$ActivateConfigParamsFromJson(
  Map<String, dynamic> json,
) => _ActivateConfigParams(
  prepared: PreparedConfigRef.fromJson(
    json['prepared'] as Map<String, dynamic>,
  ),
  setup: SetupParams.fromJson(json['setup'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ActivateConfigParamsToJson(
  _ActivateConfigParams instance,
) => <String, dynamic>{
  'prepared': instance.prepared.toJson(),
  'setup': instance.setup.toJson(),
};

_ActivatedConfigResult _$ActivatedConfigResultFromJson(
  Map<String, dynamic> json,
) => _ActivatedConfigResult(
  generation: json['generation'] as String,
  revision: (json['revision'] as num).toInt(),
);

Map<String, dynamic> _$ActivatedConfigResultToJson(
  _ActivatedConfigResult instance,
) => <String, dynamic>{
  'generation': instance.generation,
  'revision': instance.revision,
};

VpnAutoSelection _$VpnAutoSelectionFromJson(Map<String, dynamic> json) =>
    VpnAutoSelection($type: json['kind'] as String?);

Map<String, dynamic> _$VpnAutoSelectionToJson(VpnAutoSelection instance) =>
    <String, dynamic>{'kind': instance.$type};

VpnFallbackSelection _$VpnFallbackSelectionFromJson(
  Map<String, dynamic> json,
) => VpnFallbackSelection($type: json['kind'] as String?);

Map<String, dynamic> _$VpnFallbackSelectionToJson(
  VpnFallbackSelection instance,
) => <String, dynamic>{'kind': instance.$type};

VpnServerSelection _$VpnServerSelectionFromJson(Map<String, dynamic> json) =>
    VpnServerSelection(json['id'] as String, $type: json['kind'] as String?);

Map<String, dynamic> _$VpnServerSelectionToJson(VpnServerSelection instance) =>
    <String, dynamic>{'id': instance.id, 'kind': instance.$type};

_VpnServer _$VpnServerFromJson(Map<String, dynamic> json) => _VpnServer(
  id: json['id'] as String,
  name: json['name'] as String,
  target: json['target'] as String,
  type: json['type'] as String,
  provider: json['provider'] as String?,
);

Map<String, dynamic> _$VpnServerToJson(_VpnServer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'target': instance.target,
      'type': instance.type,
      'provider': instance.provider,
    };

_ProfileSnapshot _$ProfileSnapshotFromJson(Map<String, dynamic> json) =>
    _ProfileSnapshot(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      generation: json['generation'] as String?,
      routing:
          $enumDecodeNullable(_$VpnRoutingModeEnumMap, json['routing']) ??
          VpnRoutingMode.simple,
      selection: json['selection'] == null
          ? const VpnSelection.auto()
          : VpnSelection.fromJson(json['selection'] as Map<String, dynamic>),
      advancedMode:
          $enumDecodeNullable(_$ModeEnumMap, json['advancedMode']) ?? Mode.rule,
      servers:
          (json['servers'] as List<dynamic>?)
              ?.map((e) => VpnServer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      providerRefresh:
          (json['providerRefresh'] as List<dynamic>?)
              ?.map(
                (e) => VpnProviderRefresh.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      managedGroups: json['managedGroups'] == null
          ? null
          : VpnManagedGroups.fromJson(
              json['managedGroups'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$ProfileSnapshotToJson(_ProfileSnapshot instance) =>
    <String, dynamic>{
      'revision': instance.revision,
      'generation': instance.generation,
      'routing': _$VpnRoutingModeEnumMap[instance.routing]!,
      'selection': instance.selection,
      'advancedMode': _$ModeEnumMap[instance.advancedMode]!,
      'servers': instance.servers,
      'providerRefresh': instance.providerRefresh,
      'managedGroups': instance.managedGroups,
    };

const _$VpnRoutingModeEnumMap = {
  VpnRoutingMode.simple: 'simple',
  VpnRoutingMode.custom: 'custom',
};

const _$ModeEnumMap = {
  Mode.rule: 'rule',
  Mode.global: 'global',
  Mode.direct: 'direct',
};

_VpnProviderRefresh _$VpnProviderRefreshFromJson(Map<String, dynamic> json) =>
    _VpnProviderRefresh(
      section: json['section'] as String,
      name: json['name'] as String,
      interval: (json['interval'] as num).toInt(),
      lastUpdate: json['lastUpdate'] == null
          ? null
          : DateTime.parse(json['lastUpdate'] as String),
    );

Map<String, dynamic> _$VpnProviderRefreshToJson(_VpnProviderRefresh instance) =>
    <String, dynamic>{
      'section': instance.section,
      'name': instance.name,
      'interval': instance.interval,
      'lastUpdate': instance.lastUpdate?.toIso8601String(),
    };

_VpnManagedGroups _$VpnManagedGroupsFromJson(Map<String, dynamic> json) =>
    _VpnManagedGroups(
      selector: json['selector'] as String,
      auto: json['auto'] as String,
      fallback: json['fallback'] as String,
    );

Map<String, dynamic> _$VpnManagedGroupsToJson(_VpnManagedGroups instance) =>
    <String, dynamic>{
      'selector': instance.selector,
      'auto': instance.auto,
      'fallback': instance.fallback,
    };
