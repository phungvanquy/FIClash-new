import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/models/models.dart';

import 'profile_store.dart';
import 'vpn_intake.dart';
import 'vpn_import_progress.dart';
import 'vpn_staging.dart';

enum VpnImportOutcome { success, cancelled, failed, recoveryRequired }

enum VpnImportPhase { intake, download, preparation, commit }

class VpnImportResult {
  const VpnImportResult(this.outcome, {this.profile, this.phase, this.error});

  final VpnImportOutcome outcome;
  final Profile? profile;
  final VpnImportPhase? phase;
  final Object? error;

  String get diagnostic {
    final cause = switch (error) {
      DioException(:final type, :final response) =>
        'http=${type.name}, status=${response?.statusCode ?? 'none'}',
      CoreMethodException(:final code) => 'core=$code',
      FileSystemException(:final osError) =>
        'filesystem=${osError?.errorCode ?? 'unknown'}',
      _ => 'error=${error.runtimeType}',
    };
    return 'phase=${phase?.name ?? 'unknown'}, $cause';
  }

  bool get timedOut => switch (error) {
    TimeoutException() => true,
    DioException(
      type: DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout,
    ) =>
      true,
    _ => false,
  };
}

class VpnImportCancelled implements Exception {
  const VpnImportCancelled();
}

class VpnRecoveryRequired implements Exception {
  const VpnRecoveryRequired(this.failure, this.recoveryFailure);

  final Object failure;
  final Object recoveryFailure;
}

typedef VpnCommitScheduler = Future<T> Function<T>(Future<T> Function() task);

class VpnImportRequest {
  const VpnImportRequest({
    required this.profile,
    this.bytes,
    this.refreshRevision,
    this.ownedData,
    this.localResource,
    this.migrationArchive,
    this.checkCurrent,
    this.previousLegacy,
    this.localOnly = false,
    this.recordFetchTime = true,
    this.automatic = false,
    this.migrateSelection = false,
    this.expectedProfile,
    this.refreshResources,
    this.restoreData,
    this.effectiveSource,
    this.testUrl,
    this.resources = const {},
    this.onProgress,
  });

  final Profile profile;
  final List<int>? bytes;
  final int? refreshRevision;
  final ProfileOwnedData? ownedData;
  final VpnLocalResource? localResource;
  final String? migrationArchive;
  final void Function()? checkCurrent;
  final Profile? previousLegacy;
  final bool localOnly;
  final bool recordFetchTime;
  final bool automatic;
  final bool migrateSelection;
  final Profile? expectedProfile;
  final Set<String>? refreshResources;
  final ProfileRestoreData? restoreData;
  final Map<String, dynamic>? effectiveSource;
  final String? testUrl;
  final Map<String, List<int>> resources;
  final VpnProgressCallback? onProgress;
}

class VpnImportCoordinator {
  VpnImportCoordinator({
    required this.repository,
    required this.store,
    required this.stager,
    required this.serialize,
    required this.activate,
    required this.restore,
    required this.publish,
    required this.overrides,
    required this.testUrl,
    required this.maintenanceFailure,
  });

  final SingleProfileRepository repository;
  final ProfileGenerationStore store;
  final VpnCandidateStager stager;
  final VpnCommitScheduler serialize;
  final Future<void> Function(VpnPreparedCandidate) activate;
  final Future<void> Function(Profile?) restore;
  final Future<void> Function(Profile) publish;
  final Future<Map<String, dynamic>> Function(
    Profile,
    Map<String, dynamic>, {
    ProfileOwnedData? ownedData,
  })
  overrides;
  final String Function() testUrl;
  final void Function(Object, StackTrace) maintenanceFailure;

  int _intent = 0;
  bool _disposed = false;
  final Set<CancelToken> _operations = {};
  CancelToken? _explicitOperation;
  bool _needsMirrorRepair = false;

  void _reportMaintenance(Object error, StackTrace stackTrace) {
    try {
      maintenanceFailure(error, stackTrace);
    } catch (_) {}
  }

  void cancel() {
    _intent++;
    for (final token in _operations) {
      token.cancel();
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  void Function() currentIntentGuard() {
    final intent = _intent;
    return () {
      if (_disposed || intent != _intent) throw const VpnImportCancelled();
    };
  }

  Future<VpnImportResult> submit(VpnImportRequest request) async {
    final explicit = !request.automatic && request.refreshRevision == null;
    if (!explicit && _explicitOperation != null) {
      return const VpnImportResult(VpnImportOutcome.cancelled);
    }
    if (explicit) cancel();
    final intent = _intent;
    final cancelToken = CancelToken();
    _operations.add(cancelToken);
    if (explicit) _explicitOperation = cancelToken;
    var phase = VpnImportPhase.intake;
    VpnPreparedCandidate? candidate;
    var durable = false;
    void checkCurrent() {
      if (_disposed || intent != _intent || cancelToken.isCancelled) {
        throw const VpnImportCancelled();
      }
      request.checkCurrent?.call();
    }

    void progress(VpnImportProgress value) {
      if (_disposed || intent != _intent || cancelToken.isCancelled) return;
      try {
        request.onProgress?.call(value);
      } catch (_) {}
    }

    try {
      checkCurrent();
      var profile = request.profile;
      if (request.bytes == null) {
        final intake = VpnUrlIntake.parse(profile.url);
        if (intake is VpnUrlRejected) {
          return VpnImportResult(
            VpnImportOutcome.failed,
            phase: phase,
            error: intake.reason,
          );
        }
        profile = profile.copyWith(url: (intake as VpnUrlAccepted).url);
      }
      final previous = await repository.current();
      if (request.expectedProfile != null &&
          previous != request.expectedProfile) {
        throw const VpnImportCancelled();
      }
      final legacy = request.previousLegacy;
      if (legacy != null &&
          (previous != null || await repository.legacy(legacy.id) != legacy)) {
        throw const StaleProfileRevision();
      }
      final revision = previous?.snapshot.revision ?? 0;
      if (request.refreshRevision != null &&
          (request.refreshRevision != revision || previous?.id != profile.id)) {
        throw const VpnImportCancelled();
      }
      checkCurrent();
      phase = VpnImportPhase.download;
      progress(const VpnImportProgress(VpnImportStep.download));
      final VpnDownload download;
      if (request.bytes != null) {
        download = VpnDownload(request.bytes!);
      } else {
        if (request.localOnly) {
          throw const FormatException(
            'Offline import requires local configuration bytes',
          );
        }
        download = await stager.fetch(profile.url, const {}, cancelToken);
      }
      checkCurrent();
      profile = profile.copyWith(
        label: profile.label.isEmpty
            ? download.filename ?? profile.id.toString()
            : profile.label,
        subscriptionInfo: download.subscriptionInfo ?? profile.subscriptionInfo,
        order: 0,
      );
      phase = VpnImportPhase.preparation;
      progress(const VpnImportProgress(VpnImportStep.validation));
      candidate = await stager.stage(
        profile: profile,
        source: download.bytes,
        revision: revision + 1,
        testUrl: request.testUrl ?? testUrl(),
        cancel: cancelToken,
        checkCurrent: checkCurrent,
        overrides: (raw) async =>
            request.effectiveSource ??
            await overrides(profile, raw, ownedData: request.ownedData),
        resources: request.resources,
        localResource: request.localResource,
        localOnly: request.localOnly,
        refreshResources: request.refreshResources,
        recordFetchTime: request.recordFetchTime,
        migrateSelection: request.migrateSelection,
        committed: previous,
        onProgress: progress,
      );
      phase = VpnImportPhase.commit;
      final prepared = candidate;
      await serialize(() async {
        checkCurrent();
        if (_needsMirrorRepair) {
          final pending = await store.pending();
          final committed = await repository.current();
          if (pending != null &&
              committed?.snapshot.generation ==
                  pending.candidate.snapshot.generation) {
            await publish(committed!);
            await store.finishCommit(pending);
            _needsMirrorRepair = false;
          }
        }
        if (await store.pending() != null ||
            (await repository.state()).pendingRestore != null) {
          throw const VpnRecoveryRequired(
            'Unfinished commit',
            'Recovery is required before replacement',
          );
        }
        final current = await repository.current();
        if (current?.id != previous?.id ||
            (current?.snapshot.revision ?? 0) != revision) {
          throw const VpnImportCancelled();
        }
        if (request.refreshRevision != null && current != previous) {
          throw const VpnImportCancelled();
        }
        if (request.expectedProfile != null &&
            current != request.expectedProfile) {
          throw const VpnImportCancelled();
        }
        if (legacy != null && await repository.legacy(legacy.id) != legacy) {
          throw const StaleProfileRevision();
        }
        final oldRuntime = await store.runtimeBytes();
        final journal = ProfileCommitJournal(
          previous: current ?? legacy,
          candidate: prepared.profile,
          previousRevision: revision,
          previousRuntime: current?.snapshot.generation == null
              ? oldRuntime
              : null,
        );
        var activationAttempted = false;
        var runtimeAttempted = false;
        try {
          checkCurrent();
          progress(const VpnImportProgress(VpnImportStep.activating));
          await store.beginCommit(journal);
          checkCurrent();
          runtimeAttempted = true;
          await store.publishRuntime(prepared.profile);
          checkCurrent();
          activationAttempted = true;
          await activate(prepared);
          checkCurrent();
          await repository.commit(
            profile: prepared.profile,
            expectedRevision: revision,
            ownedData: request.ownedData,
            restoreData: request.restoreData,
            migrationArchive: request.migrationArchive,
            checkCurrent: checkCurrent,
          );
          durable = true;
        } catch (error) {
          try {
            if (runtimeAttempted) await store.restoreRuntimeBytes(oldRuntime);
            if (activationAttempted) await restore(current ?? legacy);
            await store.finishCommit(journal);
          } catch (recoveryError) {
            throw VpnRecoveryRequired(error, recoveryError);
          }
          rethrow;
        }
        try {
          progress(const VpnImportProgress(VpnImportStep.finalizing));
          await publish(prepared.profile);
          await store.finishCommit(journal);
        } catch (error, stackTrace) {
          _needsMirrorRepair = true;
          _reportMaintenance(error, stackTrace);
        }
      });
      return VpnImportResult(
        VpnImportOutcome.success,
        profile: prepared.profile,
      );
    } on VpnRecoveryRequired catch (error) {
      return VpnImportResult(
        VpnImportOutcome.recoveryRequired,
        phase: phase,
        error: error,
      );
    } on VpnImportCancelled {
      return VpnImportResult(VpnImportOutcome.cancelled, phase: phase);
    } on StaleProfileRevision {
      return VpnImportResult(VpnImportOutcome.cancelled, phase: phase);
    } catch (error) {
      return VpnImportResult(
        cancelToken.isCancelled
            ? VpnImportOutcome.cancelled
            : VpnImportOutcome.failed,
        phase: phase,
        error: error,
      );
    } finally {
      _operations.remove(cancelToken);
      if (identical(_explicitOperation, cancelToken)) {
        _explicitOperation = null;
      }
      if (candidate != null && !durable) {
        try {
          await stager.discard(candidate.prepared);
          final committed = await repository.current();
          if (!(await store.pinnedGenerations(
            committed,
          )).contains(candidate.profile.snapshot.generation)) {
            await store.discard(
              candidate.profile.snapshot.generation!,
              committed: committed,
            );
          }
        } catch (error, stackTrace) {
          _reportMaintenance(error, stackTrace);
        }
      }
    }
  }

  Future<void> recover() => serialize(() async {
    var current = await repository.current();
    final pending = await store.pending();
    final previous = pending?.previous;
    if (current == null &&
        previous != null &&
        previous.snapshot.generation == null) {
      current = await repository.legacy(previous.id);
      if (current != previous) {
        throw StateError('Legacy recovery profile has changed');
      }
    }
    final recovery = await store.recovery(
      committedRevision: current?.snapshot.revision ?? 0,
      committed: current,
    );
    if (recovery == null) {
      if (current != null) await publish(current);
      return;
    }
    if (current?.snapshot.generation == null) {
      await store.restoreRuntimeBytes(recovery.journal.previousRuntime);
    } else {
      await store.publishRuntime(current!);
    }
    await restore(current);
    if (current?.snapshot.generation != null) {
      await publish(current!);
    }
    await store.finishCommit(recovery.journal);
    _needsMirrorRepair = false;
  });
}
