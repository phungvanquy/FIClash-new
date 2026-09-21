import 'dart:io';

import 'package:collection/collection.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

import 'profile_store.dart';
import 'vpn_archive.dart';
import 'vpn_coordinator.dart';
import 'vpn_resources.dart';
import 'vpn_staging.dart';

class VpnMigrationResult {
  const VpnMigrationResult({
    this.profile,
    this.archive,
    this.error,
    this.complete = false,
  });

  final Profile? profile;
  final String? archive;
  final Object? error;
  final bool complete;
}

class VpnMigrationCoordinator {
  const VpnMigrationCoordinator({
    required this.repository,
    required this.store,
    required this.archives,
    required this.importer,
    required this.snapshotDatabase,
    required this.settings,
  });

  final SingleProfileRepository repository;
  final ProfileGenerationStore store;
  final VpnArchiveStore archives;
  final VpnImportCoordinator importer;
  final Future<void> Function(String) snapshotDatabase;
  final Map<String, dynamic> Function() settings;

  Future<VpnMigrationResult> run({
    int? selectedId,
    Mode advancedMode = Mode.rule,
  }) async {
    String? archive;
    final checkCurrent = importer.currentIntentGuard();
    try {
      await importer.recover();
      checkCurrent();
      final state = await repository.state();
      archive = state.migrationArchive;
      if (state.migrationVersion != 0) {
        return VpnMigrationResult(
          profile: await repository.current(),
          archive: archive,
          complete: true,
        );
      }
      final profiles = await repository.legacyProfiles();
      if (profiles.isEmpty) {
        await importer.serialize(() async {
          checkCurrent();
          await repository.completeEmptyMigration();
        });
        return const VpnMigrationResult(complete: true);
      }
      archive = (await archives.create(
        settings: settings(),
        snapshotDatabase: snapshotDatabase,
      )).path;
      checkCurrent();
      await repository.recordMigrationArchive(archive);
      final previous = profiles.firstWhereOrNull(
        (profile) => profile.id == selectedId,
      );
      final ordered = [
        ?previous,
        ...profiles.where((profile) => profile.id != previous?.id),
      ];
      final resources = VpnProfileResources(store);
      for (final profile in ordered) {
        checkCurrent();
        final List<int> bytes;
        try {
          bytes = await (await store.source(profile)).readAsBytes();
        } on FileSystemException {
          continue;
        }
        final result = await importer.submit(
          VpnImportRequest(
            profile: profile.copyWith.snapshot(
              routing: VpnRoutingMode.simple,
              advancedMode: advancedMode,
            ),
            bytes: bytes,
            previousLegacy: previous,
            localOnly: true,
            automatic: true,
            checkCurrent: checkCurrent,
            recordFetchTime: false,
            migrateSelection: true,
            migrationArchive: archive,
            localResource: (section, name, definition) =>
                resources.provider(profile, section, name, definition),
          ),
        );
        if (result.outcome == VpnImportOutcome.success) {
          return VpnMigrationResult(
            profile: result.profile,
            archive: archive,
            complete: true,
          );
        }
        if (result.outcome != VpnImportOutcome.failed ||
            result.phase == VpnImportPhase.commit ||
            !_unusableCandidate(result.error)) {
          return VpnMigrationResult(
            profile: previous,
            archive: archive,
            error: result.error,
          );
        }
      }
      await importer.serialize(() async {
        checkCurrent();
        await repository.completeEmptyMigration(archive: archive);
      });
      return VpnMigrationResult(archive: archive, complete: true);
    } catch (error) {
      return VpnMigrationResult(archive: archive, error: error);
    }
  }

  bool _unusableCandidate(Object? error) =>
      error is FormatException ||
      error is VpnLocalResourceUnavailable ||
      (error is CoreMethodException && error.code == 'prepare_failed');
}
