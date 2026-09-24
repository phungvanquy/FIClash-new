part of '../action.dart';

@Riverpod(keepAlive: true)
Future<ProfileGenerationStore> profileGenerationStore(Ref ref) async =>
    ProfileGenerationStore(Directory(await appPath.homeDirPath));

@Riverpod(keepAlive: true)
SingleProfileRepository singleProfileRepository(Ref ref) =>
    SingleProfileRepository(database);

@Riverpod(keepAlive: true)
VpnResourceFetch vpnResourceFetch(Ref ref) => request.fetchVpnResource;

@Riverpod(keepAlive: true)
class VpnMigrationState extends _$VpnMigrationState
    with AutoDisposeNotifierMixin {
  @override
  VpnMigrationResult? build() => null;
}

@Riverpod(keepAlive: true)
class VpnRefreshAction extends _$VpnRefreshAction {
  late final VpnRefreshScheduler _scheduler;
  bool _attached = true;

  @override
  void build() {
    _scheduler = VpnRefreshScheduler(
      current: () => ref.read(currentProfileProvider),
      refresh: (profile, providers, checkCurrent) async {
        final action = ref.read(vpnActionProvider.notifier);
        final result = providers == null
            ? await action.refresh(profile, checkCurrent: checkCurrent)
            : await action.refreshProviders(
                profile,
                resources: providers,
                checkCurrent: checkCurrent,
              );
        if (result.outcome == VpnImportOutcome.failed ||
            result.outcome == VpnImportOutcome.recoveryRequired) {
          commonPrint.log(
            'Scheduled VPN refresh: ${result.outcome.name}',
            logLevel: LogLevel.warning,
          );
        }
        return result;
      },
    );
    ref.onDispose(_scheduler.dispose);
    ref.listen(currentProfileProvider, (_, _) => _scheduler.reschedule());
    ref.listen(initProvider, (_, _) => _sync());
    ref.listen(vpnMigrationStateProvider, (_, _) => _sync());
    _sync();
  }

  void _sync() => _scheduler.setActive(
    _attached &&
        ref.read(initProvider) &&
        ref.read(vpnMigrationStateProvider)?.complete == true,
  );

  void setAttached(bool attached) {
    _attached = attached;
    _sync();
  }
}

@Riverpod(keepAlive: true)
class VpnAction extends _$VpnAction {
  Future<VpnImportCoordinator>? _operation;
  VpnImportCoordinator? _coordinator;
  Future<VpnMigrationResult>? _initialization;
  int _intent = 0;
  bool _disposed = false;

  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  void build() {
    ref.onDispose(() {
      _disposed = true;
      _intent++;
      _coordinator?.dispose();
    });
  }

  Future<VpnImportCoordinator> _createCoordinator() async {
    final store = await ref.read(profileGenerationStoreProvider.future);
    if (_disposed) throw const VpnImportCancelled();
    final core = _core;
    final coordinator = VpnImportCoordinator(
      repository: ref.read(singleProfileRepositoryProvider),
      store: store,
      stager: VpnCandidateStager(
        store: store,
        fetch: ref.read(vpnResourceFetchProvider),
        prepare: core.prepareConfig,
        discard: core.discardConfig,
      ),
      serialize: ref.read(setupActionProvider.notifier).serializeProfileCommit,
      activate: activateCandidate,
      restore: restoreCommitted,
      publish: publishCommitted,
      overrides: prepareOverrides,
      testUrl: () => ref.read(appSettingProvider).testUrl,
      maintenanceFailure: (error, stackTrace) {
        if (!_disposed) {
          ref.read(vpnFailureProvider.notifier).value = 'recovery_required';
        }
        commonPrint.log(
          'Profile mirror repair required: ${error.runtimeType}',
          logLevel: LogLevel.warning,
        );
      },
    );
    _coordinator = coordinator;
    return coordinator;
  }

  Future<VpnImportCoordinator> get coordinator =>
      _operation ??= _createCoordinator().onError<Object>((error, stackTrace) {
        _operation = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  void cancel() {
    _intent++;
    _coordinator?.cancel();
  }

  int get requestRevision => _intent;

  void cancelIfCurrent(int revision) {
    if (revision == _intent) cancel();
  }

  Future<VpnImportResult> submit(VpnImportRequest request) =>
      _submit(request, registerIntent: true);

  Future<VpnImportResult> _submit(
    VpnImportRequest request, {
    required bool registerIntent,
  }) async {
    if (registerIntent &&
        !request.automatic &&
        request.refreshRevision == null) {
      cancel();
    }
    final intent = _intent;
    final stopwatch = Stopwatch()..start();
    final timings = <VpnImportStep, int>{};
    VpnImportStep? step;
    var stepStarted = 0;
    void recordTiming() {
      final current = step;
      final elapsed = stopwatch.elapsedMilliseconds;
      if (current != null) {
        timings[current] = (timings[current] ?? 0) + elapsed - stepStarted;
      }
      stepStarted = elapsed;
    }

    try {
      final importer = await coordinator;
      if (_disposed || intent != _intent) {
        return const VpnImportResult(VpnImportOutcome.cancelled);
      }
      final settings = _preparationSettings;
      final result = await importer.submit(
        VpnImportRequest(
          profile: request.profile,
          bytes: request.bytes,
          refreshRevision: request.refreshRevision,
          ownedData: request.ownedData,
          localResource: request.localResource,
          migrationArchive: request.migrationArchive,
          previousLegacy: request.previousLegacy,
          localOnly: request.localOnly,
          recordFetchTime: request.recordFetchTime,
          automatic: request.automatic,
          migrateSelection: request.migrateSelection,
          expectedProfile: request.expectedProfile,
          refreshResources: request.refreshResources,
          restoreData: request.restoreData,
          effectiveSource: request.effectiveSource,
          testUrl: request.testUrl,
          resources: request.resources,
          onProgress: (progress) {
            if (progress.step != step) {
              recordTiming();
              step = progress.step;
            }
            request.onProgress?.call(progress);
          },
          checkCurrent: () {
            request.checkCurrent?.call();
            if (_preparationSettings != settings) {
              throw const VpnImportCancelled();
            }
          },
        ),
      );
      if (result.outcome == VpnImportOutcome.failed) {
        commonPrint.log(
          'VPN import failed: step=${step?.name ?? 'unknown'}, '
          '${result.diagnostic}',
          logLevel: LogLevel.warning,
        );
      }
      if (!_disposed) {
        if (result.outcome == VpnImportOutcome.recoveryRequired) {
          ref.read(vpnFailureProvider.notifier).value = 'recovery_required';
        } else if (result.outcome == VpnImportOutcome.success &&
            ref.read(vpnFailureProvider) == 'recovery_required') {
          try {
            final pending = await ref
                .read(singleProfileRepositoryProvider)
                .state();
            final journal = await (await ref.read(
              profileGenerationStoreProvider.future,
            )).pending();
            if (!_disposed &&
                intent == _intent &&
                pending.pendingRestore == null &&
                journal == null) {
              ref.read(vpnFailureProvider.notifier).value = null;
            }
          } catch (error) {
            commonPrint.log(
              'Committed profile recovery check failed: ${error.runtimeType}',
              logLevel: LogLevel.warning,
            );
          }
        }
      }
      return result;
    } on VpnImportCancelled {
      return const VpnImportResult(VpnImportOutcome.cancelled);
    } catch (error) {
      final result = VpnImportResult(VpnImportOutcome.failed, error: error);
      commonPrint.log(
        'VPN import failed: ${result.diagnostic}',
        logLevel: LogLevel.warning,
      );
      return result;
    } finally {
      recordTiming();
      stopwatch.stop();
      commonPrint.log(
        'VPN configuration processing ${stopwatch.elapsedMilliseconds}ms: '
        '${timings.entries.map((entry) => '${entry.key.name}=${entry.value}ms').join(', ')}',
      );
    }
  }

  Object get _preparationSettings => (
    ref.read(patchClashConfigProvider),
    ref.read(networkSettingProvider),
    ref.read(overrideDnsProvider),
    ref.read(appSettingProvider).testUrl,
    ref.read(authorizedTunEnableProvider),
  );

  Future<VpnImportResult> submitPreparedRestore(
    VpnImportRequest request,
    int intent,
  ) {
    if (_disposed || _intent != intent) {
      return Future.value(const VpnImportResult(VpnImportOutcome.cancelled));
    }
    return _submit(request, registerIntent: false);
  }

  Future<VpnImportResult> importUrl(
    String url, {
    VpnProgressCallback? onProgress,
  }) => submit(
    VpnImportRequest(
      profile: Profile.normal(url: url),
      onProgress: onProgress,
    ),
  );

  Future<VpnImportResult> refresh(
    Profile profile, {
    void Function()? checkCurrent,
    VpnProgressCallback? onProgress,
  }) => submit(
    VpnImportRequest(
      profile: profile,
      refreshRevision: profile.snapshot.revision,
      expectedProfile: profile,
      checkCurrent: checkCurrent,
      onProgress: onProgress,
    ),
  );

  Future<VpnImportResult> refreshProviders(
    Profile profile, {
    Set<String>? resources,
    (String, List<int>)? replacement,
    void Function()? checkCurrent,
  }) async {
    try {
      final store = await ref.read(profileGenerationStoreProvider.future);
      final bytes = await (await store.source(profile)).readAsBytes();
      return await submit(
        VpnImportRequest(
          profile: profile,
          bytes: bytes,
          refreshRevision: profile.snapshot.revision,
          expectedProfile: profile,
          refreshResources: resources,
          localOnly: replacement != null,
          recordFetchTime: false,
          checkCurrent: checkCurrent,
          localResource: (section, name, definition) async {
            if (replacement?.$1 == '$section/$name') return replacement!.$2;
            return VpnProfileResources(
              store,
            ).provider(profile, section, name, definition);
          },
        ),
      );
    } catch (error) {
      return VpnImportResult(VpnImportOutcome.failed, error: error);
    }
  }

  Future<VpnImportResult> edit(
    Profile profile, {
    List<int>? bytes,
    Profile? expected,
    ProfileOwnedData? ownedData,
  }) => _edit(profile, bytes: bytes, expected: expected, ownedData: ownedData);

  Future<VpnImportResult> setRouting(
    Profile profile,
    VpnRoutingMode routing, {
    VpnSelection? selection,
    Mode? advancedMode,
  }) => _edit(
    profile.copyWith.snapshot(
      routing: routing,
      selection: selection ?? profile.snapshot.selection,
      advancedMode: advancedMode ?? profile.snapshot.advancedMode,
    ),
    expected: profile,
  );

  Future<VpnImportResult> _edit(
    Profile profile, {
    List<int>? bytes,
    Profile? expected,
    ProfileOwnedData? ownedData,
  }) async {
    cancel();
    final intent = _intent;
    final current = await ref.read(singleProfileRepositoryProvider).current();
    if (current == null ||
        current.id != profile.id ||
        current.snapshot != (expected ?? profile).snapshot ||
        (expected != null && current != expected)) {
      return const VpnImportResult(VpnImportOutcome.cancelled);
    }
    final store = await ref.read(profileGenerationStoreProvider.future);
    final fetch = bytes == null && profile.url != current.url;
    final source = fetch
        ? null
        : bytes ?? await (await store.source(current)).readAsBytes();
    if (_disposed || intent != _intent) {
      return const VpnImportResult(VpnImportOutcome.cancelled);
    }
    return _submit(
      VpnImportRequest(
        profile: profile,
        bytes: source,
        ownedData: ownedData,
        expectedProfile: current,
        localOnly: !fetch && bytes == null,
        recordFetchTime: fetch || bytes != null,
        localResource: (section, name, definition) => VpnProfileResources(
          store,
        ).provider(current, section, name, definition),
      ),
      registerIntent: false,
    );
  }

  Future<void> updateMetadata(Profile profile) =>
      ref.read(setupActionProvider.notifier).serializeProfileCommit(() async {
        final repository = ref.read(singleProfileRepositoryProvider);
        final current = await repository.current();
        if (current == null ||
            current.id != profile.id ||
            current.snapshot != profile.snapshot ||
            current.url != profile.url ||
            current.overwriteType != profile.overwriteType ||
            current.scriptId != profile.scriptId ||
            current.matchTarget != profile.matchTarget ||
            !const MapEquality<String, String>().equals(
              current.selectedMap,
              profile.selectedMap,
            )) {
          throw const StaleProfileRevision();
        }
        await repository.update(
          expectedRevision: current.snapshot.revision,
          profile: profile,
        );
        try {
          await publishCommitted(profile);
        } catch (error) {
          commonPrint.log(
            'Profile metadata mirror repair required: ${error.runtimeType}',
            logLevel: LogLevel.warning,
          );
        }
      });

  void requireSuccess(VpnImportResult result) {
    switch (result.outcome) {
      case VpnImportOutcome.success:
        return;
      case VpnImportOutcome.cancelled:
        throw const VpnImportCancelled();
      case VpnImportOutcome.failed:
        throw MessageException(
          vpnImportFailureMessage(result, currentAppLocalizations),
        );
      case VpnImportOutcome.recoveryRequired:
        throw MessageException(currentAppLocalizations.vpnRecoveryRequired);
    }
  }

  Future<void> recover() async {
    try {
      await (await coordinator).recover();
      await repairPendingRestore();
      if (!_disposed && ref.read(vpnFailureProvider) == 'recovery_required') {
        ref.read(vpnFailureProvider.notifier).value = null;
      }
    } catch (_) {
      if (!_disposed) {
        ref.read(vpnFailureProvider.notifier).value = 'recovery_required';
      }
      rethrow;
    }
  }

  Future<VpnMigrationResult> initialize() => _initialization ??= _initialize();

  Future<VpnMigrationResult> _initialize() async {
    VpnMigrationResult result;
    try {
      if (!await _core.isInit) {
        throw const CoreMethodException(
          code: 'core_unavailable',
          message: 'Core is not initialized',
        );
      }
      final store = await ref.read(profileGenerationStoreProvider.future);
      final version = await preferences.getVersion();
      final migration = VpnMigrationCoordinator(
        repository: ref.read(singleProfileRepositoryProvider),
        store: store,
        archives: VpnArchiveStore(store.home),
        importer: await coordinator,
        snapshotDatabase: (path) =>
            database.customStatement('VACUUM INTO ?', [path]),
        settings: () => {
          ...ref.read(configProvider).toJson(),
          'version': version,
        },
      );
      result = await migration.run(
        selectedId: ref.read(currentProfileIdProvider),
        advancedMode: ref.read(patchClashConfigProvider).mode,
      );
      if (result.complete) await repairPendingRestore();
      if (result.complete && result.profile != null) {
        await publishCommitted(result.profile!);
      }
      if (result.complete && result.profile == null) {
        ref.read(profilesProvider.notifier).showSingleProfile(null);
        ref.read(currentProfileIdProvider.notifier).value = null;
        final saved = await preferences.saveConfig(ref.read(configProvider));
        final shared = await preferences.saveShareState(
          ref.read(sharedStateProvider),
        );
        if (!saved || !shared) {
          throw StateError('Empty profile preferences could not be persisted');
        }
      }
    } catch (error) {
      result = VpnMigrationResult(error: error);
    }
    if (!_disposed) ref.read(vpnMigrationStateProvider.notifier).value = result;
    if (!result.complete) _initialization = null;
    return result;
  }

  SetupParams _params(Profile? profile) => SetupParams(
    selectedMap: profile == null ? const {} : vpnRuntimeSelections(profile),
    testUrl: ref.read(appSettingProvider).testUrl,
    generation: profile?.snapshot.generation,
    revision: profile?.snapshot.generation == null
        ? null
        : profile?.snapshot.revision,
  );

  Future<void> activateCandidate(VpnPreparedCandidate candidate) async {
    var prepared = candidate.prepared;
    Future<void> activate() async {
      final result = await _core.activateConfig(
        ActivateConfigParams(
          prepared: prepared,
          setup: _params(candidate.profile).copyWith(
            testUrl: candidate.testUrl ?? ref.read(appSettingProvider).testUrl,
          ),
        ),
      );
      final snapshot = candidate.profile.snapshot;
      if (result.generation != snapshot.generation ||
          result.revision != snapshot.revision) {
        throw const CoreMethodException(
          code: 'activation_failed',
          message: 'Core activated an unexpected configuration revision',
        );
      }
    }

    try {
      await activate();
    } on CoreMethodException catch (error) {
      if (error.code != 'stale_preparation') rethrow;
      final store = await ref.read(profileGenerationStoreProvider.future);
      final snapshot = candidate.profile.snapshot;
      await store.load(snapshot.generation!);
      final result = await _core.prepareConfig(
        PrepareConfigParams(
          generation: snapshot.generation!,
          revision: snapshot.revision,
        ),
      );
      prepared = PreparedConfigRef(
        handle: result.handle,
        revision: result.revision,
      );
      try {
        if (result.generation != snapshot.generation ||
            result.revision != snapshot.revision ||
            result.servers.length != snapshot.servers.length ||
            !result.servers.every(
              (server) => snapshot.servers.any(
                (expected) =>
                    expected.id == server.id &&
                    expected.name == server.name &&
                    expected.type == server.type &&
                    expected.provider == server.provider,
              ),
            )) {
          throw const CoreMethodException(
            code: 'prepare_failed',
            message: 'Core prepared an unexpected configuration revision',
          );
        }
        await activate();
      } finally {
        await _core.discardConfig(prepared);
      }
    }
  }

  Future<void> restoreCommitted(Profile? profile) async {
    final store = await ref.read(profileGenerationStoreProvider.future);
    if (profile?.snapshot.generation != null) {
      await store.load(profile!.snapshot.generation!);
    }
    final emptyRuntime = profile == null && await store.runtimeBytes() == null;
    if (emptyRuntime) await store.restoreRuntimeBytes(utf8.encode('{}\n'));
    try {
      final error = await _core.setupConfig(params: _params(profile));
      if (error.isNotEmpty) throw MessageException(error);
    } finally {
      if (emptyRuntime) await store.restoreRuntimeBytes(null);
    }
  }

  Future<Map<String, dynamic>> prepareOverrides(
    Profile profile,
    Map<String, dynamic> source, {
    ProfileOwnedData? ownedData,
  }) async {
    final patch = ref.read(patchClashConfigProvider);
    final setup = await loadProfileSetupState(
      profile,
      dns: patch.dns,
      overrideDns: ref.read(overrideDnsProvider),
      ownedData: ownedData,
    );
    final result = await ref
        .read(setupActionProvider.notifier)
        .getProfile(
          setupState: setup,
          patchConfig: patch.copyWith.tun(
            enable:
                patch.tun.enable &&
                ref.read(authorizedTunEnableProvider) ==
                    TunAuthorizationState.authorized,
          ),
          source: source,
          staging: true,
        );
    return jsonDecode(jsonEncode(loadYaml(result.yaml)))
        as Map<String, dynamic>;
  }

  Future<String> previewDraft(ProfileEditDraft draft) async {
    final store = await ref.read(profileGenerationStoreProvider.future);
    final source = await (await store.source(draft.original)).readAsString();
    final raw =
        jsonDecode(jsonEncode(loadYaml(source))) as Map<String, dynamic>;
    return encodeYamlTask(
      await prepareOverrides(draft.profile, raw, ownedData: draft.ownedData),
    );
  }

  Future<Map<String, dynamic>> prepareRestoreSource({
    required Profile profile,
    required Map<String, dynamic> source,
    required ProfileOwnedData ownedData,
    required Config settings,
    required List<Rule> globalRules,
    Script? script,
    String? scriptContent,
  }) async {
    final patch = settings.patchClashConfig;
    final setup = await loadProfileSetupState(
      profile,
      dns: patch.dns,
      overrideDns: settings.overrideDns,
      ownedData: ownedData,
      globalRules: globalRules,
      scriptOverride: script,
    );
    final result = await ref
        .read(setupActionProvider.notifier)
        .getProfile(
          setupState: setup,
          patchConfig: patch.copyWith.tun(
            enable:
                patch.tun.enable &&
                ref.read(authorizedTunEnableProvider) ==
                    TunAuthorizationState.authorized,
          ),
          source: source,
          staging: true,
          network: settings.networkProps,
          dnsOverride: settings.overrideDns,
          suppliedScript: scriptContent,
        );
    return jsonDecode(jsonEncode(loadYaml(result.yaml)))
        as Map<String, dynamic>;
  }

  Future<(int, String)?> _applyPendingRestore() async {
    final committed = await ref.read(singleProfileRepositoryProvider).state();
    final publication = committed.pendingRestore;
    if (publication == null) return null;
    final decoded = jsonDecode(publication) as Map<String, dynamic>;
    if (decoded['version'] != 1) {
      throw const FormatException('Invalid restore publication');
    }
    final scripts = Map<String, String>.from(decoded['scripts'] as Map);
    final store = await ref.read(profileGenerationStoreProvider.future);
    final directory = Directory('${store.home.path}/scripts');
    if (scripts.isNotEmpty) {
      await directory.create(recursive: true);
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FileSystemException('Invalid script directory');
      }
    }
    for (final entry in scripts.entries) {
      final id = int.tryParse(entry.key);
      if (id == null || id <= 0 || '$id' != entry.key) {
        throw const FormatException('Invalid restored script identity');
      }
      final temporary = File('${directory.path}/.$id-restore-$uniqueId');
      try {
        await temporary.writeAsString(entry.value, flush: true);
        await temporary.rename('${directory.path}/$id.js');
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
    if (decoded['settings'] case final Map settings) {
      final config = Config.fromJson(Map<String, dynamic>.from(settings));
      ref.read(davSettingProvider.notifier).update((_) => config.davProps);
      ref.read(patchClashConfigProvider.notifier).value =
          config.patchClashConfig;
      ref.read(appSettingProvider.notifier).value = config.appSettingProps;
      ref.read(themeSettingProvider.notifier).value = config.themeProps;
      ref.read(windowSettingProvider.notifier).value = config.windowProps;
      ref.read(vpnSettingProvider.notifier).value = config.vpnProps;
      ref.read(proxiesStyleSettingProvider.notifier).value =
          config.proxiesStyleProps;
      ref.read(overrideDnsProvider.notifier).value = config.overrideDns;
      ref.read(networkSettingProvider.notifier).value = config.networkProps;
      ref.read(hotKeyActionsProvider.notifier).value = config.hotKeyActions;
    }
    return (committed.revision, publication);
  }

  Future<void> repairPendingRestore() =>
      ref.read(setupActionProvider.notifier).serializeProfileCommit(() async {
        final publication = await _applyPendingRestore();
        if (publication == null) return;
        final current = await ref
            .read(singleProfileRepositoryProvider)
            .current();
        ref.read(profilesProvider.notifier).showSingleProfile(current);
        ref.read(currentProfileIdProvider.notifier).value = current?.id;
        if (!await preferences.saveConfig(ref.read(configProvider)) ||
            !await preferences.saveShareState(ref.read(sharedStateProvider))) {
          throw StateError('Restored settings require publication repair');
        }
        await ref
            .read(singleProfileRepositoryProvider)
            .finishRestore(publication.$1, publication.$2);
      });

  Future<void> publishCommitted(Profile profile) async {
    final publication = await _applyPendingRestore();
    final previous = ref.read(currentProfileProvider);
    ref.read(profilesProvider.notifier).publishCommitted(profile);
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    if (previous?.id == profile.id &&
        previous!.snapshot.revision < profile.snapshot.revision &&
        profile.snapshot.selection is VpnAutoSelection &&
        previous.snapshot.selection is VpnServerSelection &&
        !profile.snapshot.servers.any(
          (server) =>
              server.id ==
              (previous.snapshot.selection as VpnServerSelection).id,
        )) {
      dialogs.showNotifier(currentAppLocalizations.vpnServerUnavailableAuto);
    }
    final savedConfig = await preferences.saveConfig(ref.read(configProvider));
    final savedShared = await preferences.saveShareState(
      ref.read(sharedStateProvider),
    );
    if (!savedConfig || !savedShared) {
      throw StateError('Committed profile preferences could not be persisted');
    }
    if (publication != null) {
      await ref
          .read(singleProfileRepositoryProvider)
          .finishRestore(publication.$1, publication.$2);
    }
    await ref.read(proxiesActionProvider.notifier).updateGroups();
    await ref.read(providersProvider.notifier).syncProviders();
  }
}
