part of '../action.dart';

class _DelayTestTarget {
  const _DelayTestTarget({
    required this.proxyName,
    required this.testUrl,
    required this.key,
  });

  final String proxyName;
  final String testUrl;
  final String key;
}

class _DelayTestJob {
  _DelayTestJob(Iterable<String> keys) : held = keys.toSet();

  final Set<String> held;
  bool cancelled = false;
}

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  final TaskPool _delayTestPool = TaskPool(maxConcurrentDelayTests);

  final List<_DelayTestJob> _delayTestJobs = [];

  final Map<String, String> _pendingSelectedRollback = {};
  int _selectionIntent = 0;
  bool _disposed = false;

  @override
  void build() {
    ref.onDispose(() {
      _disposed = true;
      _selectionIntent++;
    });
    ref.listen(coreStatusProvider, (_, next) {
      if (next != CoreStatus.connected) {
        cancelDelayTests();
      }
    });
  }

  void cancelDelayTests() {
    for (final job in _delayTestJobs) {
      job.cancelled = true;
      job.held.clear();
    }
    ref.read(pendingDelayTestsProvider.notifier).clear();
  }

  void updateGroupsDebounce([Duration? duration]) {
    debouncer.call(FunctionTag.updateGroups, updateGroups, duration: duration);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    if (ref.read(currentProfileProvider)?.snapshot.generation != null) {
      unawaited(changeProxy(groupName: groupName, proxyName: proxyName));
      return;
    }
    _pendingSelectedRollback.putIfAbsent(
      groupName,
      () => _currentSelectedName(groupName),
    );
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, proxyName);
    debouncer.call((FunctionTag.changeProxy, groupName), (
      String groupName,
      String proxyName,
    ) async {
      await changeProxy(groupName: groupName, proxyName: proxyName);
      updateGroupsDebounce();
    }, args: [groupName, proxyName]);
  }

  String _currentSelectedName(String groupName) {
    return ref.read(currentProfileProvider)?.selectedMap[groupName] ?? '';
  }

  Future<void> updateGroups() async {
    try {
      final profile = ref.read(currentProfileProvider);
      commonPrint.log('updateGroups');
      final groups = await retry<List<Group>>(
        task: () async {
          final sortType = ref.read(
            proxiesStyleSettingProvider.select((state) => state.sortType),
          );
          final delayMap = ref.read(delayDataSourceProvider);
          final testUrl = ref.read(
            appSettingProvider.select((state) => state.testUrl),
          );
          final selectedMap = ref.read(selectedMapProvider);
          try {
            return await _core.getProxiesGroups(
              selectedMap: selectedMap,
              sortType: sortType,
              delayMap: delayMap,
              defaultTestUrl: testUrl,
            );
          } catch (e) {
            commonPrint.log(
              'updateGroups error: $e',
              logLevel: coreFailureLogLevel(e),
            );
            return [];
          }
        },
        retryIf: (res) => res.isEmpty,
      );
      if (!_disposed && ref.read(currentProfileProvider) == profile) {
        ref.read(groupsProvider.notifier).value = groups;
      }
    } catch (e) {
      // The Core failure path already runs inside the retry task above; a
      // throw here only means ref.read hit a disposed container or the
      // groupsProvider write itself failed.
      commonPrint.log(
        'updateGroups failed: $e',
        logLevel: coreFailureLogLevel(e),
      );
    }
  }

  void updateCurrentGroupName(String groupName) {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) return;
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(currentGroupName: groupName));
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(unfoldSet: value));
  }

  void setDelay(Delay delay) {
    ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    final profile = ref.read(currentProfileProvider);
    if (profile?.snapshot.generation != null) {
      if (profile!.snapshot.routing != VpnRoutingMode.custom ||
          groupName == profile.snapshot.managedGroups?.selector) {
        return;
      }
      await _changeCommittedSelection(
        profile,
        (current) => current.copyWith(
          selectedMap: {...current.selectedMap, groupName: proxyName},
        ),
        groupName: groupName,
        proxyName: proxyName,
      );
      return;
    }
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final rollbackName =
        _pendingSelectedRollback.remove(groupName) ??
        _currentSelectedName(groupName);
    profilesAction.updateCurrentSelectedMap(groupName, proxyName);
    try {
      final message = await _core.changeProxy(
        ChangeProxyParams(groupName: groupName, proxyName: proxyName),
      );
      if (message.isNotEmpty) throw MessageException(message);
    } catch (error) {
      commonPrint.log(
        'changeProxy($groupName -> $proxyName) failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
      profilesAction.updateCurrentSelectedMap(groupName, rollbackName);
      dialogs.showNotifier(
        currentAppLocalizations.changeProxyFailedTip,
        level: MessageLevel.error,
      );
      return;
    }
    try {
      if (ref.read(appSettingProvider).closeConnections) {
        await _core.closeConnections();
      } else {
        await _core.resetConnections();
      }
    } catch (error) {
      commonPrint.log(
        'changeProxy($groupName -> $proxyName) connection reset failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<bool> selectVpn(VpnSelection selection) async {
    final profile = ref.read(currentProfileProvider);
    final groups = profile?.snapshot.managedGroups;
    if (profile == null || groups == null) return false;
    if (selection case VpnServerSelection(:final id)) {
      if (!profile.snapshot.servers.any((server) => server.id == id)) {
        return false;
      }
    }
    if (profile.snapshot.routing == VpnRoutingMode.custom) {
      _selectionIntent++;
      final action = ref.read(vpnActionProvider.notifier);
      final result = await action.setRouting(
        profile,
        VpnRoutingMode.simple,
        selection: selection,
      );
      if (result.outcome == VpnImportOutcome.cancelled) return false;
      action.requireSuccess(result);
      return true;
    }
    return _changeCommittedSelection(
      profile,
      (current) => current.copyWith.snapshot(selection: selection),
      groupName: groups.selector,
      proxyName: vpnSelectionTarget(
        selection,
        groups,
        profile.snapshot.servers,
      ),
    );
  }

  Future<bool> _changeCommittedSelection(
    Profile expected,
    Profile Function(Profile) update, {
    required String groupName,
    required String proxyName,
  }) {
    final intent = ++_selectionIntent;
    final action = ref.read(vpnActionProvider.notifier);
    action.cancel();
    final repository = ref.read(singleProfileRepositoryProvider);
    void checkCurrent() {
      if (_disposed || intent != _selectionIntent) {
        throw const VpnImportCancelled();
      }
    }

    return ref.read(setupActionProvider.notifier).serializeProfileCommit(
      () async {
        Profile? previous;
        var attempted = false;
        var committed = false;
        try {
          checkCurrent();
          previous = await repository.current();
          checkCurrent();
          if (previous == null ||
              previous.id != expected.id ||
              previous.snapshot.revision != expected.snapshot.revision ||
              previous.snapshot.generation != expected.snapshot.generation) {
            return false;
          }
          final candidate = update(previous);
          if (candidate == previous) return true;
          if (await _core.isInit) {
            checkCurrent();
            attempted = true;
            final message = await _core.changeProxy(
              ChangeProxyParams(groupName: groupName, proxyName: proxyName),
            );
            if (message.isNotEmpty) throw MessageException(message);
          }
          checkCurrent();
          await repository.update(
            expectedRevision: previous.snapshot.revision,
            profile: candidate,
            checkCurrent: checkCurrent,
          );
          committed = true;
          await action.publishCommitted(candidate);
          if (attempted) {
            if (ref.read(appSettingProvider).closeConnections) {
              await _core.closeConnections();
            } else {
              await _core.resetConnections();
            }
          }
          ref.read(checkIpNumProvider.notifier).add();
          return true;
        } catch (error) {
          if (committed) {
            commonPrint.log(
              'Selection mirror repair required: ${error.runtimeType}',
              logLevel: LogLevel.warning,
            );
            return true;
          }
          if (attempted && previous != null) {
            try {
              await action.restoreCommitted(previous);
            } catch (_) {
              throw MessageException(
                currentAppLocalizations.vpnRecoveryRequired,
              );
            }
          }
          if (error is VpnImportCancelled) return false;
          throw MessageException(currentAppLocalizations.changeProxyFailedTip);
        }
      },
    );
  }

  Future<String> updateProvider(
    ExternalProvider provider, {
    bool showLoading = false,
  }) async {
    final operation = showLoading
        ? ref
              .read(updatingKeysProvider.notifier)
              .start(provider.updatingKey, scope: UpdatingScope.core)
        : null;
    try {
      final profile = ref.read(currentProfileProvider);
      if (profile?.snapshot.generation != null) {
        final action = ref.read(vpnActionProvider.notifier);
        final result = await action.refreshProviders(
          profile!,
          resources: {
            '${provider.type == 'Proxy' ? 'proxy-providers' : 'rule-providers'}/${provider.name}',
          },
        );
        if (result.outcome != VpnImportOutcome.cancelled) {
          action.requireSuccess(result);
        }
        return '';
      }
      final message = await _core.updateExternalProvider(
        providerName: provider.name,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await _core.getExternalProvider(provider.name));
      return '';
    } finally {
      if (operation != null) {
        ref
            .read(updatingKeysProvider.notifier)
            .stop(provider.updatingKey, operation);
      }
    }
  }

  Future<String> sideLoadExternalProvider(
    ExternalProvider provider,
    String data, {
    bool showLoading = false,
  }) async {
    final operation = showLoading
        ? ref
              .read(updatingKeysProvider.notifier)
              .start(provider.updatingKey, scope: UpdatingScope.core)
        : null;
    try {
      final profile = ref.read(currentProfileProvider);
      if (profile?.snapshot.generation != null) {
        final action = ref.read(vpnActionProvider.notifier);
        final result = await action.refreshProviders(
          profile!,
          replacement: (
            '${provider.type == 'Proxy' ? 'proxy-providers' : 'rule-providers'}/${provider.name}',
            utf8.encode(data),
          ),
        );
        if (result.outcome != VpnImportOutcome.cancelled) {
          action.requireSuccess(result);
        }
        return '';
      }
      final message = await _core.sideLoadExternalProvider(
        providerName: provider.name,
        data: data,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await _core.getExternalProvider(provider.name));
      return '';
    } finally {
      if (operation != null) {
        ref
            .read(updatingKeysProvider.notifier)
            .stop(provider.updatingKey, operation);
      }
    }
  }

  Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) {
    return _runDelayTests([proxy], testUrl);
  }

  Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
    await _runDelayTests(proxies, testUrl);
    ref.read(sortNumProvider.notifier).add();
  }

  List<_DelayTestTarget> _resolveDelayTestTargets(
    List<Proxy> proxies,
    String? testUrl,
  ) {
    final groups = ref.read(groupsProvider);
    final selectedMap = ref.read(
      currentProfileProvider.select((state) => state?.selectedMap ?? {}),
    );
    final fallbackTestUrl = ref.read(realTestUrlProvider(testUrl));
    final seen = <String>{};
    final targets = <_DelayTestTarget>[];
    for (final proxy in proxies) {
      final state = computeRealSelectedProxyState(
        proxy.name,
        groups: groups,
        selectedMap: selectedMap,
      );
      if (state.proxyName.isEmpty) {
        continue;
      }
      final currentTestUrl = state.testUrl.takeFirstValid([fallbackTestUrl]);
      final key = delayTestKey(currentTestUrl, state.proxyName);
      if (!seen.add(key)) {
        continue;
      }
      targets.add(
        _DelayTestTarget(
          proxyName: state.proxyName,
          testUrl: currentTestUrl,
          key: key,
        ),
      );
    }
    return targets;
  }

  Future<void> _runDelayTests(List<Proxy> proxies, String? testUrl) async {
    final targets = _resolveDelayTestTargets(proxies, testUrl);
    if (targets.isEmpty) {
      return;
    }
    final pending = ref.read(pendingDelayTestsProvider.notifier);
    final job = _DelayTestJob(targets.map((target) => target.key));
    _delayTestJobs.add(job);
    pending.acquire(job.held);
    try {
      await Future.wait(
        targets.map(
          (target) => _delayTestPool.run(() => _runDelayTest(job, target)),
        ),
      );
    } finally {
      _delayTestJobs.remove(job);
      final abandoned = job.held.toList();
      job.held.clear();
      pending.release(abandoned);
    }
  }

  Future<void> _runDelayTest(_DelayTestJob job, _DelayTestTarget target) async {
    if (job.cancelled) {
      return;
    }
    try {
      final delay = await _core.getDelay(target.testUrl, target.proxyName);
      if (delay != null && !job.cancelled) {
        setDelay(delay);
      }
    } catch (error) {
      if (error is CoreMethodException && error.isCoreUnavailable) {
        job.cancelled = true;
      }
      commonPrint.log(
        'Delay test failed for ${target.proxyName}: $error',
        logLevel: coreFailureLogLevel(error),
      );
    } finally {
      if (job.held.remove(target.key)) {
        ref.read(pendingDelayTestsProvider.notifier).release([target.key]);
      }
    }
  }
}
