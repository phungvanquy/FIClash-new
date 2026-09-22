import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AndroidManager extends ConsumerStatefulWidget {
  final Widget child;

  const AndroidManager({super.key, required this.child});

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager>
    with ServiceListener {
  Service? _service;

  @override
  void initState() {
    super.initState();
    _service = ref.read(androidServiceProvider);
    ref.listenManual(appSettingProvider.select((state) => state.hidden), (
      prev,
      next,
    ) {
      app?.updateExcludeFromRecents(next);
    }, fireImmediately: true);
    ref.listenManual(loadedLocaleProvider, (prev, next) {
      if (prev != null && prev != next) {
        app?.initShortcuts();
      }
    });
    ref.listenManual(sharedStateProvider, (prev, next) {
      if (prev != next) {
        debouncer.call(FunctionTag.saveSharedFile, () async {
          await preferences.saveShareState(next);
        }, duration: const Duration(seconds: 1));
        if (prev?.needSyncSharedState != next.needSyncSharedState) {
          _service?.syncState(next.needSyncSharedState);
        }
      }
    });
    _service?.addListener(this);
    unawaited(ref.read(setupActionProvider.notifier).syncRunState());
    app?.onPackagesChanged = _reloadPackages;
  }

  void _reloadPackages() {
    if (ref.read(packagesProvider).isEmpty) {
      return;
    }
    unawaited(ref.read(systemActionProvider.notifier).getPackages());
  }

  @override
  void dispose() {
    if (app?.onPackagesChanged == _reloadPackages) {
      app?.onPackagesChanged = null;
    }
    _service?.removeListener(this);
    super.dispose();
  }

  @override
  void onServiceEvent(CoreEvent event) {
    coreEventManager.sendEvent(event);
    super.onServiceEvent(event);
  }

  @override
  void onRunState(AndroidRunObservation observation) {
    ref.read(setupActionProvider.notifier).observeAndroid(observation);
  }

  @override
  void onRunStateUnavailable() {
    unawaited(ref.read(setupActionProvider.notifier).syncRunState());
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
