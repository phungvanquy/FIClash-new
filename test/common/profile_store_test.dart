import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/profile_store.dart';
import 'package:fl_clash/common/task.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Interrupted implements Exception {}

Future<Profile> _stage(ProfileGenerationStore store, int revision) async {
  final generation = await store.allocate();
  final profile = Profile(
    id: revision,
    autoUpdateDuration: const Duration(hours: 24),
    url: 'https://example.test/subscription?token=$revision',
    snapshot: ProfileSnapshot(
      generation: generation,
      revision: revision,
      servers: [
        VpnServer(
          id: 'node-$revision',
          name: 'Node',
          target: 'target',
          type: 'Vless',
        ),
      ],
    ),
  );
  await store.write(generation, 'source.yaml', utf8.encode('source $revision'));
  await store.write(
    generation,
    'effective.yaml',
    utf8.encode('effective $revision'),
  );
  await store.write(
    generation,
    'providers/proxies/a.yaml',
    utf8.encode('provider $revision'),
  );
  await store.seal(profile);
  return profile;
}

void main() {
  late Directory home;
  late ProfileGenerationStore store;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('flclash-profile-store-');
    store = ProfileGenerationStore(home);
  });

  tearDown(() async => home.delete(recursive: true));

  test(
    'sealed snapshots load offline and reject writes or changed resources',
    () async {
      final profile = await _stage(store, 1);
      final generation = profile.snapshot.generation!;
      expect(await ProfileGenerationStore(home).load(generation), profile);
      expect(await (await store.source(profile)).readAsString(), 'source 1');
      await expectLater(
        store.write(generation, 'source.yaml', []),
        throwsStateError,
      );
      await store
          .resource(generation, 'providers/proxies/a.yaml')
          .writeAsString('changed');
      await expectLater(store.load(generation), throwsFormatException);
      expect(
        (await store.load(generation, verify: false)).snapshot.servers,
        profile.snapshot.servers,
      );
      expect(await store.catalog(profile), profile.snapshot.servers);
      await expectLater(
        store.catalog(
          profile.copyWith(snapshot: profile.snapshot.copyWith(revision: 2)),
        ),
        throwsStateError,
      );
    },
  );

  test('legacy source lookup does not create missing or empty files', () async {
    const legacy = Profile(id: 12, autoUpdateDuration: Duration.zero);
    await expectLater(
      store.source(legacy),
      throwsA(isA<FileSystemException>()),
    );
    final source = File(p.join(home.path, 'profiles', '12.yaml'));
    await source.parent.create(recursive: true);
    await source.writeAsString('legacy source');
    expect(await (await store.source(legacy)).readAsString(), 'legacy source');
    await expectLater(store.publishRuntime(legacy), throwsStateError);
  });

  test(
    'path traversal, symbolic links and unowned cleanup are rejected',
    () async {
      final generation = await store.allocate();
      for (final path in [
        '/escape',
        '../escape',
        'nested/../../escape',
        r'nested\escape',
        'C:/escape',
        'nested//file',
      ]) {
        expect(() => store.resource(generation, path), throwsArgumentError);
      }
      expect(() => store.directory('../escape'), throwsArgumentError);
      final outside = await Directory.systemTemp.createTemp('flclash-outside-');
      addTearDown(() => outside.delete(recursive: true));
      if (!Platform.isWindows) {
        await Link(
          p.join(store.directory(generation).path, 'linked'),
        ).create(outside.path);
        await expectLater(
          store.write(generation, 'linked/file', []),
          throwsA(isA<FileSystemException>()),
        );
        expect(await outside.list().isEmpty, isTrue);
      }
      await expectLater(
        ProfileGenerationStore(home).discard(generation, committed: null),
        throwsStateError,
      );
      await store.discard(generation, committed: null);
      expect(await store.directory(generation).exists(), isFalse);
    },
  );

  test(
    'pending journal pins both generations and refuses competing commits',
    () async {
      final previous = await _stage(store, 1);
      final candidate = await _stage(store, 2);
      final journal = ProfileCommitJournal(
        previous: previous,
        candidate: candidate,
        previousRevision: 1,
      );
      await store.beginCommit(journal);
      expect(await store.pinnedGenerations(previous), {
        previous.snapshot.generation,
        candidate.snapshot.generation,
      });
      await expectLater(
        store.discard(candidate.snapshot.generation!, committed: previous),
        throwsStateError,
      );
      await expectLater(store.beginCommit(journal), throwsStateError);
      await expectLater(
        store.recovery(committedRevision: 3, committed: previous),
        throwsStateError,
      );
      await store.finishCommit(journal);
      await store.discard(candidate.snapshot.generation!, committed: previous);
      expect(
        await store.directory(previous.snapshot.generation!).exists(),
        isTrue,
      );
    },
  );

  for (final boundary in [
    ProfileStoreCheckpoint.journalFlushed,
    ProfileStoreCheckpoint.journalPublished,
    ProfileStoreCheckpoint.runtimeFlushed,
    ProfileStoreCheckpoint.runtimePublished,
    ProfileStoreCheckpoint.journalRemoved,
    null,
  ]) {
    test(
      'interruption at ${boundary?.name ?? 'database commit'} recovers the committed revision',
      () async {
        var armed = false;
        store = ProfileGenerationStore(
          home,
          checkpoint: (point) async {
            if (armed && point == boundary) throw _Interrupted();
          },
        );
        final previous = await _stage(store, 1);
        final candidate = await _stage(store, 2);
        await store.publishRuntime(previous);
        var committed = previous;
        final journal = ProfileCommitJournal(
          previous: previous,
          candidate: candidate,
          previousRevision: 1,
        );
        armed = true;
        try {
          await store.beginCommit(journal);
          await store.publishRuntime(candidate);
          committed = candidate;
          if (boundary == null) throw _Interrupted();
          await store.finishCommit(journal);
          fail('Interruption was not reached');
        } on _Interrupted {
          final reopened = ProfileGenerationStore(home);
          final recovery = await reopened.recovery(
            committedRevision: committed.snapshot.revision,
            committed: committed,
          );
          if (recovery != null) {
            expect(recovery.profile, committed);
            expect(
              recovery.kind,
              committed == previous
                  ? ProfileRecoveryKind.rollback
                  : ProfileRecoveryKind.finalize,
            );
            await reopened.publishRuntime(recovery.profile!);
            await reopened.finishCommit(recovery.journal);
          }
          expect(
            await File(p.join(home.path, 'config.yaml')).readAsString(),
            'effective ${committed.snapshot.revision}',
          );
          expect(await reopened.pending(), isNull);
          expect(await reopened.load(previous.snapshot.generation!), previous);
          expect(
            await reopened.load(candidate.snapshot.generation!),
            candidate,
          );
        }
      },
    );
  }

  test(
    'partial unpublished resource write leaves committed content and journal untouched',
    () async {
      final previous = await _stage(store, 1);
      await store.publishRuntime(previous);
      store = ProfileGenerationStore(
        home,
        checkpoint: (_) async => throw _Interrupted(),
      );
      final generation = await store.allocate();
      await expectLater(
        store.write(generation, 'source.yaml', utf8.encode('candidate')),
        throwsA(isA<_Interrupted>()),
      );
      expect(await store.pending(), isNull);
      expect(
        await File(p.join(home.path, 'config.yaml')).readAsString(),
        'effective 1',
      );
      expect(await store.load(previous.snapshot.generation!), previous);
      await store.discard(generation, committed: previous);
    },
  );

  test(
    'routine cleanup preserves active, journal-pinned and archived resources',
    () async {
      final previous = await _stage(store, 1);
      final candidate = await _stage(store, 2);
      await store.beginCommit(
        ProfileCommitJournal(
          previous: previous,
          candidate: candidate,
          previousRevision: 1,
        ),
      );
      final profiles = Directory(p.join(home.path, 'profiles'));
      for (final id in [1, 2, 3]) {
        await File(
          p.join(profiles.path, '$id.yaml'),
        ).writeAsString('legacy $id');
        await Directory(
          p.join(profiles.path, 'providers', '$id'),
        ).create(recursive: true);
      }
      final archive = File(p.join(home.path, 'recovery', 'legacy.zip'));
      await archive.parent.create();
      await archive.writeAsString('archive');
      final protected = await store.protectedProfileIds([candidate.id]);
      final orphans = shakeOrphanFiles(
        profileIds: protected,
        scriptIds: [],
        profilesDirPath: profiles.path,
        providersDirPath: p.join(profiles.path, 'providers'),
        scriptsDirPath: p.join(home.path, 'scripts'),
      );
      expect(orphans.toSet(), {
        p.join(profiles.path, '3.yaml'),
        p.join(profiles.path, 'providers', '3'),
      });
      expect(await archive.exists(), isTrue);
      expect(await store.load(previous.snapshot.generation!), previous);
      expect(await store.load(candidate.snapshot.generation!), candidate);
    },
  );
}
