import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart' as fl;
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v4 upgrade preserves the committed snapshot and adds restore journal',
    () async {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      final seed = fl.Database(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      const profile = Profile(
        id: 8,
        label: 'Saved',
        autoUpdateDuration: Duration(hours: 1),
        snapshot: ProfileSnapshot(revision: 1),
      );
      await seed.singleProfile.commit(
        profile: profile,
        expectedRevision: 0,
        migrationArchive: 'recovery/legacy.zip',
      );
      await seed.close();
      raw.execute(
        'ALTER TABLE profile_commit_state DROP COLUMN pending_restore',
      );
      raw.execute('PRAGMA user_version = 4');
      final migrated = fl.Database(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(migrated.close);
      expect(
        await migrated.singleProfile.current(),
        profile.copyWith(order: 0),
      );
      final state = await migrated.singleProfile.state();
      expect(state.revision, 1);
      expect(state.migrationArchive, 'recovery/legacy.zip');
      expect(state.pendingRestore, isNull);
      expect(raw.select('PRAGMA user_version').single['user_version'], 5);
    },
  );

  test(
    'v3 migration preserves legacy rows until archive-backed cutover',
    () async {
      final raw = sqlite3.openInMemory();
      addTearDown(raw.close);
      final seed = fl.Database(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      const legacy = Profile(
        id: 1,
        label: 'Offline usable',
        autoUpdateDuration: Duration(hours: 24),
      );
      await seed.profilesDao.setAll([legacy, legacy.copyWith(id: 2)]);
      await seed.close();
      raw.execute('DROP TRIGGER single_profile_insert');
      raw.execute('DROP TRIGGER single_profile_update');
      raw.execute('ALTER TABLE profiles DROP COLUMN snapshot');
      raw.execute('DROP TABLE profile_commit_state');
      raw.execute('PRAGMA user_version = 3');

      final migrated = fl.Database(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      final rows = await migrated.profilesDao.query().get();
      expect(rows.map((profile) => profile.id), [1, 2]);
      expect(rows.first.snapshot, const ProfileSnapshot());
      expect((await migrated.singleProfile.state()).migrationVersion, 0);
      expect(await migrated.singleProfile.current(), isNull);
      await migrated.singleProfile.commit(
        profile: rows.first.copyWith(
          snapshot: const ProfileSnapshot(revision: 1),
        ),
        expectedRevision: 0,
        migrationArchive: 'recovery/legacy.zip',
      );
      await migrated.close();

      final reopened = fl.Database(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(reopened.close);
      expect((await reopened.singleProfile.current())?.id, 1);
      expect(
        (await reopened.singleProfile.state()).migrationArchive,
        'recovery/legacy.zip',
      );
      expect((await reopened.singleProfile.state()).revision, 1);
      expect(await reopened.profilesDao.query().get(), hasLength(1));
      expect(raw.select('PRAGMA user_version').single['user_version'], 5);
    },
  );
}
