import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('import diagnostics identify failures without private data', () {
    const secret = 'https://example.test/sub?token=private';
    final cases = <Object, String>{
      DioException(
        requestOptions: RequestOptions(path: secret),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: secret),
          statusCode: 403,
        ),
        message: secret,
      ): 'http=badResponse, status=403',
      const CoreMethodException(
        code: 'prepare_failed',
        message: secret,
        details: {'resource': secret},
      ): 'core=prepare_failed',
      const CoreMethodException(
        code: 'prepare_failed',
        message: secret,
        details: {'stage': 'candidate_read', 'osError': 5, 'path': secret},
      ): 'core=prepare_failed, stage=candidate_read, filesystem=5',
      const CoreMethodException(
        code: secret,
        message: secret,
        details: {'stage': secret, 'osError': secret},
      ): 'core=unknown, stage=unknown',
      const FileSystemException(secret, secret, OSError(secret, 5)):
          'filesystem=5',
      const FormatException(secret): 'error=FormatException',
    };
    for (final entry in cases.entries) {
      final result = VpnImportResult(
        VpnImportOutcome.failed,
        phase: VpnImportPhase.preparation,
        error: entry.key,
      );
      expect(result.diagnostic, 'phase=preparation, ${entry.value}');
      expect(result.diagnostic, isNot(contains(secret)));
    }
  });

  late Directory home;
  late Database db;
  late ProfileGenerationStore store;
  late VpnImportCoordinator coordinator;
  late Profile previous;
  late Profile? active;
  late List<int> previousRuntime;
  late VpnResourceFetch fetch;
  late Future<void> Function(VpnPreparedCandidate) activate;
  var failRestore = false;
  var failPublish = false;
  ProfileStoreCheckpoint? failCheckpoint;
  late List<Object> maintenance;
  const body =
      'proxies: [{name: Alpha, type: socks5, server: 127.0.0.1, port: 1080}]';
  const incoming = Profile(
    id: 2,
    label: 'New',
    url: 'https://example.test/new?token=a%2Bb',
    autoUpdateDuration: Duration(hours: 1),
  );

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-coordinator-test-');
    db = Database(NativeDatabase.memory());
    failRestore = false;
    failPublish = false;
    failCheckpoint = null;
    maintenance = [];
    store = ProfileGenerationStore(
      home,
      checkpoint: (point) async {
        if (point == failCheckpoint) {
          failCheckpoint = null;
          throw const FileSystemException('simulated disk failure');
        }
      },
    );
    fetch = (_, _, _) async => VpnDownload(utf8.encode(body));
    var handle = 0;
    final stager = VpnCandidateStager(
      store: store,
      fetch: (url, headers, token) => fetch(url, headers, token),
      prepare: (params) async => PreparedConfigResult(
        handle: 'prepared-${++handle}',
        generation: params.generation,
        revision: params.revision,
        servers: const [
          VpnServer(
            id: 'inline/QWxwaGE',
            name: 'Alpha',
            target: 'Alpha',
            type: 'Socks5',
          ),
        ],
      ),
      discard: (_) async => true,
    );
    final old = await stager.stage(
      profile: incoming.copyWith(
        id: 1,
        label: 'Previous',
        order: 0,
        snapshot: const ProfileSnapshot(selection: VpnSelection.fallback()),
      ),
      source: utf8.encode('# Original bytes\n$body'),
      revision: 1,
      testUrl: 'https://example.test/check',
      cancel: CancelToken(),
      checkCurrent: () {},
      overrides: (raw) async => raw,
    );
    await stager.discard(old.prepared);
    await db.singleProfile.commit(profile: old.profile, expectedRevision: 0);
    previous = (await db.singleProfile.current())!;
    await store.publishRuntime(previous);
    previousRuntime = (await store.runtimeBytes())!;
    active = previous;
    activate = (candidate) async {
      active = candidate.profile;
    };
    final scheduler = SerialTaskScheduler();
    coordinator = VpnImportCoordinator(
      repository: db.singleProfile,
      store: store,
      stager: stager,
      serialize: scheduler.run,
      activate: (candidate) => activate(candidate),
      restore: (profile) async {
        if (failRestore) throw StateError('simulated recovery failure');
        active = profile;
      },
      publish: (profile) async {
        if (failPublish) throw StateError('simulated preference failure');
      },
      overrides: (_, raw, {ownedData}) async => raw,
      testUrl: () => 'https://example.test/check',
      maintenanceFailure: (error, _) => maintenance.add(error),
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await db.close();
    await home.delete(recursive: true);
  });

  Future<void> expectPreserved() async {
    expect(await db.singleProfile.current(), previous);
    expect(await db.profilesDao.query().get(), [previous]);
    expect(await store.runtimeBytes(), previousRuntime);
    expect(active, previous);
    expect(await store.load(previous.snapshot.generation!), previous);
  }

  test(
    'reports success only after one durable profile and runtime commit',
    () async {
      final result = await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      expect(result.outcome, VpnImportOutcome.success);
      expect(await db.singleProfile.current(), result.profile);
      expect(active, result.profile);
      expect(result.profile!.snapshot.selection, const VpnSelection.auto());
      expect(result.profile!.snapshot.revision, 2);
      expect(await db.profilesDao.query().get(), [result.profile]);
      expect(await store.pending(), isNull);
      expect(await store.load(previous.snapshot.generation!), previous);
    },
  );

  test('HTTP failure preserves bytes, metadata and selection', () async {
    fetch = (_, _, _) async => throw const HttpException('offline');
    final result = await coordinator.submit(
      const VpnImportRequest(profile: incoming),
    );
    expect(result.outcome, VpnImportOutcome.failed);
    expect(result.phase, VpnImportPhase.download);
    await expectPreserved();
  });

  test(
    'refresh retains missing usage metadata but a changed URL clears it',
    () async {
      const info = SubscriptionInfo(download: 10, total: 100);
      fetch = (_, _, _) async =>
          VpnDownload(utf8.encode(body), subscriptionInfo: info);
      final imported = (await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      )).profile!;
      fetch = (_, _, _) async => VpnDownload(utf8.encode(body));
      final refreshed = await coordinator.submit(
        VpnImportRequest(
          profile: imported,
          refreshRevision: imported.snapshot.revision,
        ),
      );
      expect(refreshed.outcome, VpnImportOutcome.success);
      expect(refreshed.profile!.subscriptionInfo, info);
      final changed = await coordinator.submit(
        VpnImportRequest(
          profile: refreshed.profile!.copyWith(
            url: 'https://example.test/other',
          ),
          expectedProfile: refreshed.profile,
        ),
      );
      expect(changed.outcome, VpnImportOutcome.success);
      expect(changed.profile!.subscriptionInfo, isNull);
    },
  );

  test(
    'download timeout is a retryable failure and preserves the active profile',
    () async {
      fetch = (_, _, _) async => throw TimeoutException('download');
      final result = await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      expect(result.outcome, VpnImportOutcome.failed);
      expect(result.phase, VpnImportPhase.download);
      await expectPreserved();
    },
  );

  test(
    'stage progress follows transaction boundaries and observer errors are isolated',
    () async {
      final progress = <VpnImportStep>[];
      final result = await coordinator.submit(
        VpnImportRequest(
          profile: incoming,
          onProgress: (value) {
            progress.add(value.step);
            if (value.step == VpnImportStep.validation) {
              throw StateError('view disposed');
            }
          },
        ),
      );
      expect(result.outcome, VpnImportOutcome.success);
      expect(progress, [
        VpnImportStep.download,
        VpnImportStep.validation,
        VpnImportStep.validation,
        VpnImportStep.validation,
        VpnImportStep.saving,
        VpnImportStep.activating,
        VpnImportStep.finalizing,
      ]);
      expect(await db.singleProfile.current(), result.profile);
    },
  );

  test(
    'cancellation during saving cleans the candidate without announcing activation',
    () async {
      final progress = <VpnImportStep>[];
      final result = await coordinator.submit(
        VpnImportRequest(
          profile: incoming,
          onProgress: (value) {
            progress.add(value.step);
            if (value.step == VpnImportStep.saving) coordinator.cancel();
          },
        ),
      );
      expect(result.outcome, VpnImportOutcome.cancelled);
      expect(progress.last, VpnImportStep.saving);
      expect(await store.generations.list().length, 1);
      await expectPreserved();
    },
  );

  test(
    'invalid configuration leaves the committed snapshot unchanged',
    () async {
      final result = await coordinator.submit(
        VpnImportRequest(profile: incoming, bytes: utf8.encode('proxies: [')),
      );
      expect(result.outcome, VpnImportOutcome.failed);
      expect(result.phase, VpnImportPhase.preparation);
      await expectPreserved();
      expect(await store.generations.list().length, 1);
    },
  );

  test('disk failure rolls back the runtime file before activation', () async {
    failCheckpoint = ProfileStoreCheckpoint.runtimePublished;
    final result = await coordinator.submit(
      const VpnImportRequest(profile: incoming),
    );
    expect(result.outcome, VpnImportOutcome.failed);
    await expectPreserved();
    expect(await store.pending(), isNull);
  });

  test('activation failure restores the old runtime and profile', () async {
    activate = (candidate) async {
      active = candidate.profile;
      throw StateError('listener failure');
    };
    final result = await coordinator.submit(
      const VpnImportRequest(profile: incoming),
    );
    expect(result.outcome, VpnImportOutcome.failed);
    await expectPreserved();
    expect(await store.pending(), isNull);
  });

  test(
    'database failure after activation restores the complete old snapshot',
    () async {
      await db.customStatement(
        "CREATE TRIGGER fail_commit BEFORE UPDATE ON profile_commit_state BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      final result = await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      expect(result.outcome, VpnImportOutcome.failed);
      await expectPreserved();
      expect(await store.pending(), isNull);
    },
  );

  test(
    'newer failed intake still supersedes an older pending import',
    () async {
      final downloading = Completer<void>();
      final download = Completer<VpnDownload>();
      fetch = (_, _, _) {
        downloading.complete();
        return download.future;
      };
      final first = coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      await downloading.future;
      final second = await coordinator.submit(
        VpnImportRequest(profile: incoming.copyWith(id: 3, url: 'invalid')),
      );
      expect(second.outcome, VpnImportOutcome.failed);
      download.complete(VpnDownload(utf8.encode(body)));
      expect((await first).outcome, VpnImportOutcome.cancelled);
      await expectPreserved();
    },
  );

  test('late refresh cannot resurrect a replaced profile', () async {
    final downloading = Completer<void>();
    final download = Completer<VpnDownload>();
    fetch = (_, _, _) {
      downloading.complete();
      return download.future;
    };
    final refresh = coordinator.submit(
      VpnImportRequest(profile: previous, refreshRevision: 1),
    );
    await downloading.future;
    final replacement = await coordinator.submit(
      VpnImportRequest(profile: incoming, bytes: utf8.encode(body)),
    );
    expect(replacement.outcome, VpnImportOutcome.success);
    download.complete(VpnDownload(utf8.encode(body)));
    expect((await refresh).outcome, VpnImportOutcome.cancelled);
    expect((await db.singleProfile.current())!.id, incoming.id);
    expect(active!.id, incoming.id);
  });

  test(
    'automatic refresh cannot overtake an explicit pending import',
    () async {
      final downloading = Completer<void>();
      final download = Completer<VpnDownload>();
      fetch = (_, _, _) {
        downloading.complete();
        return download.future;
      };
      final replacement = coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      await downloading.future;
      final refresh = await coordinator.submit(
        VpnImportRequest(profile: previous, refreshRevision: 1),
      );
      expect(refresh.outcome, VpnImportOutcome.cancelled);
      download.complete(VpnDownload(utf8.encode(body)));
      expect((await replacement).outcome, VpnImportOutcome.success);
      expect((await db.singleProfile.current())!.id, incoming.id);
    },
  );

  test(
    'disposal invalidates pending work even when the downloader ignores cancellation',
    () async {
      final downloading = Completer<void>();
      final download = Completer<VpnDownload>();
      fetch = (_, _, _) {
        downloading.complete();
        return download.future;
      };
      final pending = coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      await downloading.future;
      coordinator.dispose();
      download.complete(VpnDownload(utf8.encode(body)));
      expect((await pending).outcome, VpnImportOutcome.cancelled);
      await expectPreserved();
    },
  );

  test(
    'cancellation during activation restores previous selection and bytes',
    () async {
      final activating = Completer<void>();
      final release = Completer<void>();
      activate = (candidate) async {
        active = candidate.profile;
        activating.complete();
        await release.future;
      };
      final pending = coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      await activating.future;
      coordinator.cancel();
      release.complete();
      expect((await pending).outcome, VpnImportOutcome.cancelled);
      await expectPreserved();
    },
  );

  test(
    'failed restoration keeps pinned resources and a recoverable journal',
    () async {
      activate = (candidate) async {
        active = candidate.profile;
        throw StateError('activation failed');
      };
      failRestore = true;
      final result = await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      expect(result.outcome, VpnImportOutcome.recoveryRequired);
      expect(await db.singleProfile.current(), previous);
      final journal = (await store.pending())!;
      expect(
        await store.load(journal.candidate.snapshot.generation!),
        journal.candidate,
      );
      failRestore = false;
      await coordinator.recover();
      await expectPreserved();
      expect(await store.pending(), isNull);
    },
  );

  test(
    'post-commit preference failure is success with repairable mirrors',
    () async {
      failPublish = true;
      final result = await coordinator.submit(
        const VpnImportRequest(profile: incoming),
      );
      expect(result.outcome, VpnImportOutcome.success);
      expect(await db.singleProfile.current(), result.profile);
      expect(maintenance, hasLength(1));
      expect(await store.pending(), isNotNull);
      failPublish = false;
      await coordinator.recover();
      expect(await store.pending(), isNull);
      expect(await db.singleProfile.current(), result.profile);
    },
  );

  test(
    'interrupted legacy migration recovers saved runtime bytes and selections',
    () async {
      await db.customStatement('DELETE FROM profile_commit_state');
      await db.delete(db.profiles).go();
      final legacy = previous.copyWith(
        snapshot: const ProfileSnapshot(),
        selectedMap: {'Original': 'Kept'},
      );
      await db.profiles.put(legacy.toCompanion(0));
      final legacyRuntime = utf8.encode('# original generated runtime\n$body');
      await store.restoreRuntimeBytes(legacyRuntime);
      active = legacy;
      activate = (candidate) async {
        active = candidate.profile;
        throw StateError('migration activation failed');
      };
      failRestore = true;
      final result = await coordinator.submit(
        VpnImportRequest(
          profile: legacy,
          previousLegacy: legacy,
          bytes: utf8.encode(body),
          localOnly: true,
          migrationArchive: 'recovery/verified.zip',
        ),
      );
      expect(result.outcome, VpnImportOutcome.recoveryRequired);
      final journal = (await store.pending())!;
      expect(journal.previous, legacy);
      expect(journal.previousRuntime, legacyRuntime);
      await store.restoreRuntimeBytes(utf8.encode('interrupted replacement'));
      failRestore = false;
      await coordinator.recover();
      expect(await store.runtimeBytes(), legacyRuntime);
      expect(active, legacy);
      expect(await db.profilesDao.query().get(), [legacy]);
      expect(await db.singleProfile.current(), isNull);
      expect(await store.pending(), isNull);
    },
  );

  test(
    'a later import repairs mirrors without reactivating the old commit',
    () async {
      var activations = 0;
      activate = (candidate) async {
        activations++;
        active = candidate.profile;
      };
      failPublish = true;
      expect(
        (await coordinator.submit(
          const VpnImportRequest(profile: incoming),
        )).outcome,
        VpnImportOutcome.success,
      );
      failPublish = false;
      final result = await coordinator.submit(
        VpnImportRequest(profile: incoming.copyWith(id: 3)),
      );
      expect(result.outcome, VpnImportOutcome.success);
      expect(activations, 2);
      expect(await store.pending(), isNull);
      expect(await db.singleProfile.current(), result.profile);
    },
  );
}
