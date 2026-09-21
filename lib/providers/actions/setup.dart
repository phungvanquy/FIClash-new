part of '../action.dart';

enum _SetupTaskResult { completed, handoffToCoreRestart, failed }

class _RunRequest {
  final bool running;
  final bool initialize;

  const _RunRequest({required this.running, required this.initialize});
}

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  Timer? _runtimeTimer;
  final _setupScheduler = SerialTaskScheduler();
  final _listenerScheduler = SerialTaskScheduler();
  _RunRequest? _latestRunRequest;
  DateTime? _startTime;
  bool get _requestedRunning => ref.read(vpnRunRequestedProvider);

  set _requestedRunning(bool value) {
    ref.read(vpnRunRequestedProvider.notifier).value = value;
  }

  bool get runningRequested =>
      _requestedRunning ||
      (_latestRunRequest == null && ref.read(runTimeProvider) != null);

  bool get _isRunning => runningRequested;

  ({bool running, Object? request}) get restartIntent =>
      (running: runningRequested, request: _latestRunRequest);

  bool shouldResumeAfterRestart(({bool running, Object? request}) previous) =>
      runningRequested ||
      (!system.isAndroid &&
          identical(previous.request, _latestRunRequest) &&
          previous.running);

  @override
  void build() {
    ref.onDispose(() {
      _runtimeTimer?.cancel();
      _runtimeTimer = null;
    });
  }

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    final snapshot = ref.read(currentProfileProvider)?.snapshot;
    return SetupParams(
      selectedMap: selectedMap,
      testUrl: testUrl,
      generation: snapshot?.generation,
      revision: snapshot?.generation == null ? null : snapshot?.revision,
    );
  }

  Future<T> serializeProfileCommit<T>(Future<T> Function() task) =>
      _setupScheduler.run(task);

  Future<bool> fullSetup() async {
    if (!ref.read(initProvider)) return true;
    ref.read(proxiesActionProvider.notifier).cancelDelayTests();
    ref.read(delayDataSourceProvider.notifier).value = {};
    final setupResult = applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(maxLogsLength);
    ref.read(requestsProvider.notifier).value = FixedList(maxRequestsLength);
    try {
      return await setupResult;
    } catch (e, s) {
      commonPrint.log('fullSetup ===> ${compactError(e)}, $s');
      return false;
    }
  }

  void _setLocalRunning(bool running) {
    _runtimeTimer?.cancel();
    _runtimeTimer = null;
    if (!running) {
      _startTime = null;
      debouncer.cancel(FunctionTag.applyProfile);
      _updateRunTime();
      return;
    }

    _startTime ??= DateTime.now();
    _refreshRunningState();
    _runtimeTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRunningState(),
    );
  }

  void _refreshRunningState() {
    _updateRunTime();
    unawaited(ref.read(commonActionProvider.notifier).updateTraffic());
  }

  void _updateRunTime() {
    final startTime = _startTime;
    ref.read(runTimeProvider.notifier).value = startTime == null
        ? null
        : DateTime.now().millisecondsSinceEpoch -
              startTime.millisecondsSinceEpoch;
  }

  void observeAndroid(AndroidRunObservation observation) {
    if (!ref.read(androidRunStateProvider.notifier).observe(observation)) {
      return;
    }
    if (ref.read(vpnPendingProvider) == null && !ref.read(suspendProvider)) {
      _requestedRunning =
          observation.state == VpnRunState.starting ||
          observation.state == VpnRunState.started;
    }
    final active =
        observation.startedAt > 0 &&
        (observation.state == VpnRunState.started ||
            observation.state == VpnRunState.stopping);
    if (active) {
      _startTime = DateTime.fromMillisecondsSinceEpoch(observation.startedAt);
    }
    _setLocalRunning(active);
  }

  void observeCore(CoreRunObservation observation) {
    if (!ref.read(coreRunStateProvider.notifier).observe(observation)) return;
    if (system.isAndroid) return;
    if (ref.read(vpnPendingProvider) == null && !ref.read(suspendProvider)) {
      _requestedRunning = observation.requested;
    }
    _setLocalRunning(observation.active && !observation.suspended);
  }

  void coreUnavailable() {
    _setLocalRunning(false);
    ref.read(vpnFailureProvider.notifier).value = 'core_unavailable';
  }

  Future<void> syncRunState() async {
    try {
      if (system.isAndroid) {
        final observation = await service?.getRunState();
        if (ref.mounted && observation != null) observeAndroid(observation);
      } else if (ref.read(coreStatusProvider) == CoreStatus.connected) {
        final observation = await _core.getRunState();
        if (ref.mounted) observeCore(observation);
      }
    } catch (_) {
      commonPrint.log(
        'Run-state snapshot unavailable',
        logLevel: LogLevel.warning,
      );
    }
  }

  Future<void> reconcileSuspension() => _listenerScheduler.run(() async {
    if (!ref.mounted || !runningRequested) return;
    final suspended = ref.read(suspendProvider);
    try {
      if (!await setCoreRunning(!suspended)) {
        ref.read(vpnFailureProvider.notifier).value =
            'listener_transition_failed';
      }
    } finally {
      await syncRunState();
    }
  });

  Future<void> initStatus() async {
    if (_latestRunRequest != null) return;
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    await syncRunState();
    if (_latestRunRequest != null) return;
    final shouldRun = _isRunning || ref.read(appSettingProvider).autoRun;
    if (shouldRun) {
      await setRunning(true, initialize: true);
    } else {
      await globalState.safeRun(() => applyProfile(force: true));
    }
  }

  Future<bool> setRunning(bool running, {bool initialize = false}) async {
    if (running && !initialize && !ref.read(initProvider)) {
      return true;
    }
    if (running && ref.read(vpnFailureProvider) == 'recovery_required') {
      throw MessageException(currentAppLocalizations.vpnRecoveryRequired);
    }

    final request = _RunRequest(
      running: running,
      initialize: running && initialize,
    );
    _latestRunRequest = request;
    _requestedRunning = running;
    ref.read(vpnPendingProvider.notifier).value = running;
    if (ref.read(vpnFailureProvider) != 'recovery_required') {
      ref.read(vpnFailureProvider.notifier).value = null;
    }
    if (!running) debouncer.cancel(FunctionTag.applyProfile);
    if (request.initialize) {
      globalState.needInitStatus = false;
    }
    try {
      if (running && !initialize) {
        await _applyConnectDefaults();
        if (!_isCurrent(request)) return true;
      }
      return await (running ? _start(request) : _stop(request));
    } catch (_) {
      _rollbackRunning(request);
      rethrow;
    } finally {
      if (ref.mounted && _isCurrent(request)) {
        ref.read(vpnPendingProvider.notifier).value = null;
      }
    }
  }

  Future<void> _applyConnectDefaults() async {
    if (!ref.read(appSettingProvider).vpnDefaultsPending) return;
    if (system.isDesktop) {
      ref
          .read(patchClashConfigProvider.notifier)
          .update((value) => value.copyWith.tun(enable: true));
    } else if (system.isAndroid) {
      ref
          .read(vpnSettingProvider.notifier)
          .update((value) => value.copyWith(enable: true));
    }
    ref
        .read(appSettingProvider.notifier)
        .update((value) => value.copyWith(vpnDefaultsPending: false));
    if (!await preferences.saveConfig(ref.read(configProvider))) {
      ref
          .read(appSettingProvider.notifier)
          .update((value) => value.copyWith(vpnDefaultsPending: true));
      throw StateError('Unable to persist VPN defaults');
    }
  }

  Future<bool> _start(_RunRequest request) async {
    try {
      final applied = await applyProfile(
        force: true,
        silence: true,
        preloadInvoke: () => _setCoreRunning(request),
      );
      if (!applied) throw StateError('configuration_failed');
    } catch (_) {
      _rollbackRunning(request);
      if (_isCurrent(request)) {
        await _listenerScheduler.run(() async {
          if (!_isCurrent(request)) return;
          try {
            await setCoreRunning(false);
          } catch (_) {
            ref.read(vpnFailureProvider.notifier).value = 'recovery_required';
          } finally {
            await syncRunState();
          }
        });
      }
      if (request.initialize) return false;
      rethrow;
    }
    return true;
  }

  Future<bool> _stop(_RunRequest request) async {
    try {
      await _setCoreRunning(request);
    } catch (_) {
      _rollbackRunning(request);
      rethrow;
    }
    if (!_isCurrent(request)) {
      return true;
    }
    resetCoreTraffic();
    ref.read(trafficsProvider.notifier).clear();
    ref.read(totalTrafficProvider.notifier).value = const Traffic();
    ref.read(checkIpNumProvider.notifier).add();
    return true;
  }

  Future<void> _setCoreRunning(_RunRequest request) {
    return _listenerScheduler.run(() async {
      if (!_isCurrent(request)) {
        return;
      }
      if (request.running && ref.read(suspendProvider)) {
        return;
      }
      try {
        if (!await setCoreRunning(request.running)) {
          throw StateError(
            request.running ? 'listener_start_failed' : 'listener_stop_failed',
          );
        }
      } finally {
        await syncRunState();
      }
    });
  }

  void _rollbackRunning(_RunRequest request) {
    if (!_isCurrent(request)) {
      return;
    }
    _requestedRunning = !request.running;
    if (ref.read(vpnFailureProvider) != 'recovery_required') {
      ref.read(vpnFailureProvider.notifier).value = request.running
          ? 'start_failed'
          : 'stop_failed';
    }
  }

  bool _isCurrent(_RunRequest request) => identical(_latestRunRequest, request);

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, updateConfig);
  }

  @protected
  Future<bool> setCoreRunning(bool running) {
    return running ? _core.startListener() : _core.stopListener();
  }

  @protected
  void resetCoreTraffic() {
    _core.resetTraffic();
  }

  @visibleForTesting
  Future<void> updateConfig() async {
    await globalState.safeRun(() async {
      final updateParams = ref.read(updateParamsProvider);
      final shouldContinueSetup =
          !_isRunning || await requestAdmin(updateParams.tun.enable);
      if (!shouldContinueSetup) {
        await _restartCoreAfterAuthorization();
        return;
      }
      final message = await serializeProfileCommit(() {
        final snapshot = ref.read(currentProfileProvider)?.snapshot;
        return _core.updateConfig(
          updateParams.copyWith(
            mode: snapshot?.generation == null
                ? updateParams.mode
                : snapshot!.routing == VpnRoutingMode.simple
                ? Mode.global
                : snapshot.advancedMode,
            tun: updateParams.tun.copyWith(
              enable: _getEffectiveTunEnable(updateParams.tun.enable),
            ),
          ),
        );
      });
      ref.read(checkIpNumProvider.notifier).add();
      if (message.isNotEmpty) throw MessageException(message);
    });
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  Future<void> changeMode(Mode mode) async {
    final profile = ref.read(currentProfileProvider);
    if (profile?.snapshot.generation != null) {
      await globalState.safeRun(() async {
        final action = ref.read(vpnActionProvider.notifier);
        final result = await action.setRouting(
          profile!,
          VpnRoutingMode.custom,
          advancedMode: mode,
        );
        if (result.outcome != VpnImportOutcome.cancelled) {
          action.requireSuccess(result);
        }
      });
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _runSetup(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
    );
    return result != _SetupTaskResult.failed;
  }

  Future<_SetupTaskResult> _runSetup({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    final result = await _setupScheduler.run(() {
      return _setupConfig(
        force: force,
        silence: silence,
        preloadInvoke: preloadInvoke,
        onUpdated: () async {
          await ref.read(proxiesActionProvider.notifier).updateGroups();
          await ref.read(providersProvider.notifier).syncProviders();
        },
      );
    });
    if (result != _SetupTaskResult.handoffToCoreRestart) {
      return result;
    }
    // Release the current serial task before restartCore reapplies the profile.
    final restarted = await _restartCoreAfterAuthorization();
    return restarted ? _SetupTaskResult.completed : _SetupTaskResult.failed;
  }

  Future<bool> _restartCoreAfterAuthorization() async {
    try {
      return await ref.read(coreActionProvider.notifier).restartCore();
    } catch (_) {
      ref.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.none;
      rethrow;
    }
  }

  Future<({String yaml, String md5})> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
    Map<String, dynamic>? source,
    bool staging = false,
    NetworkProps? network,
    bool? dnsOverride,
    String? suppliedScript,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return (yaml: '', md5: '');
    final defaultUA = globalState.packageInfo.ua;
    final NetworkProps networkSetting =
        network ?? ref.read(networkSettingProvider);
    final bool overrideDns = dnsOverride ?? ref.read(overrideDnsProvider);
    final appendSystemDns = networkSetting.appendSystemDns;
    final routeMode = networkSetting.routeMode;
    final generation = ref
        .read(profileProvider(profileId))
        ?.snapshot
        .generation;
    final configMap =
        source ?? await _core.getConfig(profileId, generation: generation);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (setupState.overwriteType == OverwriteType.script) {
      scriptContent = suppliedScript ?? await setupState.script?.content;
    } else if (setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
        authentication: networkSetting.authentication.credentials,
        confineProviderPaths: !staging,
        matchTarget: setupState.matchTarget,
      ),
    );
    return res;
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.yaml;
    } catch (e) {
      dialogs.showNotifier(e.toString(), level: MessageLevel.error);
    }
    return '';
  }

  bool _getEffectiveTunEnable(bool enableTun) {
    final authorizationState = ref.read(authorizedTunEnableProvider);
    return enableTun && authorizationState == TunAuthorizationState.authorized;
  }

  @protected
  Future<AuthorizeCode> authorizeCore() {
    return system.authorizeCore();
  }

  @visibleForTesting
  Future<bool> requestAdmin(bool enableTun) async {
    if (!enableTun) {
      return true;
    }
    final authorizationState = ref.read(authorizedTunEnableProvider);
    if (authorizationState != TunAuthorizationState.none) {
      return true;
    }

    final authorizationNotifier = ref.read(
      authorizedTunEnableProvider.notifier,
    );
    authorizationNotifier.value = TunAuthorizationState.unauthorized;

    final code = await authorizeCore();

    switch (code) {
      case AuthorizeCode.success:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return false;
      case AuthorizeCode.none:
        authorizationNotifier.value = TunAuthorizationState.authorized;
        return true;
      case AuthorizeCode.error:
        return true;
    }
  }

  /// An empty profile list is left alone: it is the first-run state, and it is
  /// what the profile stream holds before its first emission.
  @visibleForTesting
  Profile? recoverMissingProfile() {
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return null;
    final profiles = ref.read(profilesProvider);
    if (profiles.isEmpty) return null;
    final fallback = profiles.first;
    commonPrint.log(
      'profile $profileId is missing, falling back to ${fallback.id}',
      logLevel: LogLevel.warning,
    );
    ref.read(currentProfileIdProvider.notifier).value = fallback.id;
    return fallback;
  }

  Future<_SetupTaskResult> _setupConfig({
    bool force = false,
    bool silence = false,
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider) ?? recoverMissingProfile();
    if (profile?.snapshot.generation != null) {
      return _setupSnapshot(
        profile!,
        preloadInvoke: preloadInvoke,
        onUpdated: onUpdated,
      );
    }
    // A refresh failure is surfaced by safeRun; setup keeps the old profile.
    final nextProfile = await globalState.safeRun(
      () => profile?.checkAndUpdateAndCopy(
        validate: (path) => _core.validateConfig(path),
      ),
    );
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.realLabel}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final shouldContinueSetup =
        !_isRunning || await requestAdmin(patchConfig.tun.enable);
    if (!shouldContinueSetup) {
      return _SetupTaskResult.handoffToCoreRestart;
    }
    final effectiveTunEnable = _getEffectiveTunEnable(patchConfig.tun.enable);
    final realPatchConfig = patchConfig.copyWith.tun(
      enable: effectiveTunEnable,
    );
    final realProfile = await globalState.safeRun(() async {
      final setupState = await ref.read(setupStateProvider(profile?.id).future);
      return getProfile(setupState: setupState, patchConfig: realPatchConfig);
    }, title: 'build profile');
    final profileFailed = realProfile == null;
    final yamlString = realProfile?.yaml ?? '';
    final yamlMd5 = realProfile?.md5 ?? '';
    if (!profileFailed && yamlMd5 == globalState.lastConfigMd5 && !force) {
      return _SetupTaskResult.completed;
    }
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      await preferences.saveShareState(sharedState);
    }
    // Recaptured so _start's catch can roll back after safeRun swallows it.
    (Object, StackTrace)? handoffFailure;
    var setupFailed = false;
    await globalState.loadingRun(
      () async {
        try {
          final configFilePath = await appPath.configFilePath;
          await File(configFilePath).safeWriteAsString(yamlString);
          final profileId = profile?.id;
          if (profileId != null) {
            await appPath.ensureProviderDirs(profileId);
          }
          final message = await _core.setupConfig(
            params: _setupParams,
            preloadInvoke: preloadInvoke,
          );
          if (message.isNotEmpty) {
            throw MessageException(message);
          }
        } catch (e, s) {
          setupFailed = true;
          if (preloadInvoke != null) {
            handoffFailure = (e, s);
          }
          rethrow;
        }
        globalState.lastConfigMd5 = yamlMd5;
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
    if (handoffFailure != null) {
      Error.throwWithStackTrace(handoffFailure!.$1, handoffFailure!.$2);
    }
    if (setupFailed || profileFailed) {
      return _SetupTaskResult.failed;
    }
    return _SetupTaskResult.completed;
  }

  Future<_SetupTaskResult> _setupSnapshot(
    Profile profile, {
    Future<void> Function()? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    final patch = ref.read(patchClashConfigProvider);
    if (_isRunning && !await requestAdmin(patch.tun.enable)) {
      return _SetupTaskResult.handoffToCoreRestart;
    }
    try {
      final store = await ref.read(profileGenerationStoreProvider.future);
      await store.load(profile.snapshot.generation!);
      await store.publishRuntime(profile);
      final params = SetupParams(
        selectedMap: vpnRuntimeSelections(profile),
        testUrl: ref.read(appSettingProvider).testUrl,
        generation: profile.snapshot.generation,
        revision: profile.snapshot.revision,
      );
      final applied = await _core.setupConfig(params: params);
      if (applied.isNotEmpty) throw MessageException(applied);
      final updates = ref.read(updateParamsProvider);
      final updated = await _core.updateConfig(
        updates.copyWith(
          mode: profile.snapshot.routing == VpnRoutingMode.simple
              ? Mode.global
              : profile.snapshot.advancedMode,
          tun: updates.tun.copyWith(
            enable: _getEffectiveTunEnable(updates.tun.enable),
          ),
        ),
      );
      if (updated.isNotEmpty) throw MessageException(updated);
      await preloadInvoke?.call();
      await preferences.saveShareState(ref.read(sharedStateProvider));
      ref.read(checkIpNumProvider.notifier).add();
      await onUpdated?.call();
      return _SetupTaskResult.completed;
    } catch (error) {
      if (preloadInvoke != null) rethrow;
      commonPrint.log(
        'Snapshot setup failed: ${error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      return _SetupTaskResult.failed;
    }
  }
}
