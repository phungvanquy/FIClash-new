import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

class VpnConfiguration {
  const VpnConfiguration({
    required this.effective,
    required this.servers,
    required this.groups,
    required this.selection,
    required this.selectedMap,
  });

  final Map<String, dynamic> effective;
  final List<VpnServer> servers;
  final VpnManagedGroups groups;
  final VpnSelection selection;
  final Map<String, String> selectedMap;
}

VpnConfiguration buildVpnConfiguration({
  required Map<String, dynamic> source,
  required List<VpnServer> catalog,
  required String generation,
  required String testUrl,
  VpnRoutingMode routing = VpnRoutingMode.simple,
  VpnSelection selection = const VpnSelection.auto(),
  Mode advancedMode = Mode.rule,
  Map<String, String> advancedSelections = const {},
}) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(generation)) {
    throw const FormatException('Invalid content generation');
  }
  if (catalog.isEmpty) {
    throw const FormatException('Configuration contains no usable servers');
  }
  final effective = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  final sourceGroups = effective['proxy-groups'] as List? ?? [];
  final sourceProxies = effective['proxies'] as List? ?? [];
  final occupied = <String>{
    'GLOBAL',
    'DIRECT',
    'REJECT',
    'REJECT-DROP',
    'COMPATIBLE',
    'PASS',
    'PASS-RULE',
    for (final item in [...sourceGroups, ...sourceProxies])
      if (item is Map && item['name'] is String) item['name'] as String,
    for (final server in catalog) server.name,
    ...?(effective['proxy-providers'] as Map?)?.keys.cast<String>(),
  };
  String allocate(String suffix) {
    final base = '__flclash_${generation}_$suffix';
    var name = base;
    for (var attempt = 1; !occupied.add(name); attempt++) {
      name = '${base}_$attempt';
    }
    return name;
  }

  final groups = VpnManagedGroups(
    selector: allocate('select'),
    auto: allocate('auto'),
    fallback: allocate('fallback'),
  );
  final managed = <Map<String, dynamic>>[];
  final identities = <String>{};
  final servers = <VpnServer>[];
  for (final server in catalog) {
    if (server.id.isEmpty ||
        server.name.isEmpty ||
        !identities.add(server.id)) {
      throw const FormatException('Ambiguous server identity');
    }
    final provider = server.provider;
    if (provider == null) {
      if (!sourceProxies.any(
        (item) => item is Map && item['name'] == server.name,
      )) {
        throw const FormatException('Missing inline server');
      }
      servers.add(server.copyWith(target: server.name));
      continue;
    }
    if ((effective['proxy-providers'] as Map?)?.containsKey(provider) != true) {
      throw const FormatException('Missing server provider');
    }
    final alias = allocate('server_${servers.length}');
    managed.add({
      'name': alias,
      'type': 'select',
      'use': [provider],
      'filter': _exactProviderName(server.name),
      'empty-fallback': 'REJECT',
      'hidden': true,
    });
    servers.add(server.copyWith(target: alias));
  }
  final targets = servers.map((server) => server.target).toList();
  for (final (name, type) in [
    (groups.auto, 'url-test'),
    (groups.fallback, 'fallback'),
  ]) {
    managed.add({
      'name': name,
      'type': type,
      'proxies': List<String>.of(targets),
      'url': testUrl,
      'interval': 300,
      'lazy': false,
      'empty-fallback': 'REJECT',
      'hidden': true,
    });
  }
  managed.add({
    'name': groups.selector,
    'type': 'select',
    'proxies': [groups.auto, groups.fallback, ...targets],
    'empty-fallback': 'REJECT',
    'hidden': true,
  });
  final resolved = switch (selection) {
    VpnServerSelection(:final id) when !identities.contains(id) =>
      const VpnSelection.auto(),
    _ => selection,
  };
  final selectedMap = Map<String, String>.of(advancedSelections);
  selectedMap[groups.selector] = vpnSelectionTarget(resolved, groups, servers);
  if (routing == VpnRoutingMode.simple) {
    effective['mode'] = Mode.global.name;
    effective['proxy-groups'] = [
      for (final group in sourceGroups)
        if (group is! Map || group['name'] != 'GLOBAL') group,
      ...managed,
      {
        'name': 'GLOBAL',
        'type': 'select',
        'proxies': [groups.selector],
        'empty-fallback': 'REJECT',
        'hidden': true,
      },
    ];
    selectedMap['GLOBAL'] = groups.selector;
  } else {
    effective['mode'] = advancedMode.name;
    effective['proxy-groups'] = [...sourceGroups, ...managed];
  }
  return VpnConfiguration(
    effective: effective,
    servers: List.unmodifiable(servers),
    groups: groups,
    selection: resolved,
    selectedMap: Map.unmodifiable(selectedMap),
  );
}

String vpnSelectionTarget(
  VpnSelection selection,
  VpnManagedGroups groups,
  List<VpnServer> servers,
) => switch (selection) {
  VpnAutoSelection() => groups.auto,
  VpnFallbackSelection() => groups.fallback,
  VpnServerSelection(:final id) =>
    servers.firstWhere((server) => server.id == id).target,
};

Map<String, String> vpnRuntimeSelections(Profile profile) {
  final groups = profile.snapshot.managedGroups;
  if (groups == null) return profile.selectedMap;
  return {
    ...profile.selectedMap,
    groups.selector: vpnSelectionTarget(
      profile.snapshot.selection,
      groups,
      profile.snapshot.servers,
    ),
    if (profile.snapshot.routing == VpnRoutingMode.simple)
      'GLOBAL': groups.selector,
  };
}

VpnSelection legacyVpnSelection(
  Profile profile,
  List<VpnServer> catalog,
  Map<String, dynamic> source,
) {
  final groups = <String, Map>{
    for (final group in source['proxy-groups'] as List? ?? const [])
      if (group is Map && group['name'] is String)
        group['name'] as String: group,
  };
  var target = profile.currentGroupName;
  if (target == null || !groups.containsKey(target)) {
    target = profile.selectedMap['GLOBAL'];
  }
  final visited = <String>{};
  while (target != null && groups.containsKey(target) && visited.add(target)) {
    final group = groups[target]!;
    if (group['type'] == 'url-test') return const VpnSelection.auto();
    if (group['type'] == 'fallback') return const VpnSelection.fallback();
    target = profile.selectedMap[target];
  }
  final names = target == null ? profile.selectedMap.values.toSet() : {target};
  final matches = catalog
      .where((server) => names.contains(server.name))
      .toList();
  return matches.length == 1
      ? VpnSelection.server(matches.single.id)
      : const VpnSelection.auto();
}

String _exactProviderName(String name) {
  final escaped = name.replaceAllMapped(
    RegExp(r'[\\.^$|?*+()\[\]{}]'),
    (match) => '\\${match[0]}',
  );
  return r'\A' + escaped.replaceAll('`', r'\x60') + r'\z';
}
