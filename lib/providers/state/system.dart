part of '../state.dart';

@riverpod
VpnConnection vpnConnection(Ref ref) {
  return deriveVpnConnection(
    android: system.isAndroid,
    coreReady: ref.watch(coreStatusProvider) == CoreStatus.connected,
    suspended: ref.watch(suspendProvider),
    systemProxyRequested: ref.watch(
      networkSettingProvider.select((value) => value.systemProxy),
    ),
    core: ref.watch(coreRunStateProvider),
    native: ref.watch(androidRunStateProvider),
    proxy: ref.watch(systemProxyStateProvider),
    pending: ref.watch(vpnPendingProvider),
    runRequested: ref.watch(vpnRunRequestedProvider),
    failure: ref.watch(vpnFailureProvider),
  );
}

@riverpod
UpdateParams updateParams(Ref ref) {
  final routeMode = ref.watch(
    networkSettingProvider.select((state) => state.routeMode),
  );
  final authentication = ref.watch(
    networkSettingProvider.select((state) => state.authentication),
  );
  return ref.watch(
    patchClashConfigProvider.select(
      (state) => UpdateParams(
        tun: state.tun.getRealTun(routeMode),
        authentication: authentication.credentials,
        allowLan: state.allowLan,
        findProcessMode: state.findProcessMode,
        mode: state.mode,
        logLevel: state.logLevel,
        ipv6: state.ipv6,
        tcpConcurrent: state.tcpConcurrent,
        externalController: state.externalController,
        unifiedDelay: state.unifiedDelay,
        mixedPort: state.mixedPort,
        geoAutoUpdate: state.geoAutoUpdate,
        geoUpdateInterval: state.geoUpdateInterval,
      ),
    ),
  );
}

@riverpod
TrayState trayState(Ref ref) {
  final connection = ref.watch(vpnConnectionProvider);
  final isStart = switch (connection.phase) {
    VpnConnectionPhase.connected ||
    VpnConnectionPhase.proxyOnly ||
    VpnConnectionPhase.localProxy => true,
    _ => false,
  };
  final systemProxy = ref.watch(
    networkSettingProvider.select((state) => state.systemProxy),
  );
  final clashConfig = ref.watch(
    patchClashConfigProvider.select(
      (state) => (
        mode: state.mode,
        mixedPort: state.mixedPort,
        tunEnable: state.tun.enable,
      ),
    ),
  );
  final appSetting = ref.watch(
    appSettingProvider.select(
      (state) =>
          (autoLaunch: state.autoLaunch, showTrayTitle: state.showTrayTitle),
    ),
  );
  final groups = ref.watch(currentGroupsStateProvider).value;
  final selectedMap = ref.watch(selectedMapProvider);

  return TrayState(
    mode: clashConfig.mode,
    port: clashConfig.mixedPort,
    autoLaunch: appSetting.autoLaunch,
    systemProxy: systemProxy,
    tunEnable: connection.phase == VpnConnectionPhase.connected,
    isStart: isStart,
    groups: groups,
    selectedMap: selectedMap,
    showTrayTitle: appSetting.showTrayTitle,
    connection: connection,
    profile: ref.watch(currentProfileProvider),
  );
}

@riverpod
TrayTitleState trayTitleState(Ref ref) {
  final showTrayTitle = ref.watch(
    appSettingProvider.select((state) => state.showTrayTitle),
  );
  final traffic = ref.watch(
    trafficsProvider.select((state) => state.list.safeLast(const Traffic())),
  );
  return TrayTitleState(showTrayTitle: showTrayTitle, traffic: traffic);
}

@riverpod
VpnState vpnState(Ref ref) {
  final vpnProps = ref.watch(vpnSettingProvider);
  final stack = ref.watch(
    patchClashConfigProvider.select((state) => state.tun.stack),
  );
  return VpnState(stack: stack, vpnProps: vpnProps);
}

@riverpod
PackageListSelectorState packageListSelectorState(Ref ref) {
  final packages = ref.watch(packagesProvider);
  final accessControlProps = ref.watch(
    vpnSettingProvider.select((state) => state.accessControlProps),
  );
  return PackageListSelectorState(
    packages: packages,
    accessControlProps: accessControlProps,
  );
}

@riverpod
HotKeyAction getHotKeyAction(Ref ref, HotAction hotAction) {
  return ref.watch(
    hotKeyActionsProvider.select((state) {
      final index = state.indexWhere((item) => item.action == hotAction);
      return index != -1 ? state[index] : HotKeyAction(action: hotAction);
    }),
  );
}

@riverpod
({bool isInit, int checkIpNum, bool containsDetection}) checkIp(Ref ref) {
  final isInit = ref.watch(initProvider);
  final checkIpNum = ref.watch(checkIpNumProvider);
  final containsDetection = ref.watch(
    dashboardStateProvider.select(
      (state) =>
          state.dashboardWidgets.contains(DashboardWidget.networkDetection),
    ),
  );
  return (
    isInit: isInit,
    checkIpNum: checkIpNum,
    containsDetection: containsDetection,
  );
}

@riverpod
bool shouldPatchSystemDns(Ref ref) {
  final autoSetSystemDns = ref.watch(
    networkSettingProvider.select((state) => state.autoSetSystemDns),
  );
  if (!autoSetSystemDns) {
    return false;
  }
  final observed = ref.watch(coreRunStateProvider);
  final ready = ref.watch(coreStatusProvider) == CoreStatus.connected;
  final authorizationState = ref.watch(authorizedTunEnableProvider);
  return ready &&
      observed?.active == true &&
      observed?.tun == true &&
      observed?.suspended == false &&
      !ref.watch(suspendProvider) &&
      authorizationState == TunAuthorizationState.authorized;
}

@riverpod
SharedState sharedState(Ref ref) {
  ref.watch(loadedLocaleProvider);
  final currentProfile = ref.watch(
    currentProfileProvider.select(
      (state) => CurrentProfileSelectorState(
        label: state?.label ?? '',
        selectedMap: state?.selectedMap ?? {},
      ),
    ),
  );
  final snapshot = ref.watch(
    currentProfileProvider.select((profile) => profile?.snapshot),
  );
  final appSetting = ref.watch(
    appSettingProvider.select(
      (state) => (
        onlyStatisticsProxy: state.onlyStatisticsProxy,
        showStopAction: state.showNotificationStopAction,
        crashlytics: state.crashlytics,
        testUrl: state.testUrl,
      ),
    ),
  );
  final networkSetting = ref.watch(
    networkSettingProvider.select(
      (state) => (
        bypassDomain: state.bypassDomain,
        routeMode: state.routeMode,
        authenticated: state.authentication.credentials.isNotEmpty,
      ),
    ),
  );
  final clashConfig = ref.watch(
    patchClashConfigProvider.select(
      (state) => (
        stack: state.tun.stack.name,
        mixedPort: state.mixedPort,
        routeAddress: state.tun.resolveRouteAddress(networkSetting.routeMode),
      ),
    ),
  );
  final vpnSetting = ref.watch(vpnSettingProvider);
  final currentProfileName = currentProfile.label;
  final selectedMap = ref.watch(selectedMapProvider);
  final onlyStatisticsProxy = appSetting.onlyStatisticsProxy;
  final crashlytics = appSetting.crashlytics;
  final testUrl = appSetting.testUrl;
  final stack = clashConfig.stack;
  final port = clashConfig.mixedPort;
  return SharedState(
    currentProfileName: currentProfileName,
    onlyStatisticsProxy: onlyStatisticsProxy,
    showStopAction: appSetting.showStopAction,
    stopText: currentAppLocalizations.stop,
    crashlytics: crashlytics,
    stopTip: currentAppLocalizations.stopVpn,
    startTip: currentAppLocalizations.startVpn,
    setupParams: SetupParams(
      selectedMap: selectedMap,
      testUrl: testUrl,
      generation: snapshot?.generation,
      revision: snapshot?.generation == null ? null : snapshot?.revision,
    ),
    vpnOptions: VpnOptions(
      enable: vpnSetting.enable,
      stack: stack,
      // VpnService.setHttpProxy cannot carry credentials, so an authenticated
      // mixed port must not be declared as the system HTTP proxy; traffic
      // still flows through TUN.
      systemProxy: vpnSetting.systemProxy && !networkSetting.authenticated,
      port: port,
      ipv6: vpnSetting.ipv6,
      dnsHijacking: vpnSetting.dnsHijacking,
      accessControlProps: vpnSetting.accessControlProps,
      allowBypass: vpnSetting.allowBypass,
      bypassDomain: networkSetting.bypassDomain,
      routeAddress: clashConfig.routeAddress,
    ),
  );
}

@riverpod
class AccessControlState extends _$AccessControlState
    with AutoDisposeNotifierMixin {
  @override
  AccessControlProps build() => const AccessControlProps();
}

@riverpod
bool suspend(Ref ref) {
  final currentSSID = ref.watch(currentSSIDProvider);
  final excludeSSIDs = ref.watch(excludeSSIDsProvider);
  return excludeSSIDs.contains(currentSSID);
}
