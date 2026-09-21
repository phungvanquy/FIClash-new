import 'package:drift/native.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Profile candidate(int id, int revision) => Profile(
  id: id,
  label: 'Profile $id',
  autoUpdateDuration: const Duration(hours: 24),
  url: 'https://example.test/config?token=$id',
  snapshot: ProfileSnapshot(
    revision: revision,
    generation: id.toRadixString(16).padLeft(32, '0'),
    servers: [
      VpnServer(
        id: 'server-$id',
        name: 'Server $id',
        target: 'node-$id',
        type: 'Vless',
      ),
    ],
  ),
);

void main() {
  late Database db;
  late SingleProfileRepository repository;

  setUp(() {
    db = Database(NativeDatabase.memory());
    repository = db.singleProfile;
  });

  tearDown(() async => db.close());

  test(
    'legacy recovery lookup is unavailable after migration commits',
    () async {
      final legacy = candidate(
        1,
        1,
      ).copyWith(snapshot: const ProfileSnapshot(), order: 0);
      await db.profiles.put(legacy.toCompanion());
      expect(await repository.legacy(1), legacy);
      await repository.commit(
        profile: candidate(1, 1),
        expectedRevision: 0,
        migrationArchive: 'recovery/verified.zip',
      );
      expect(await repository.legacy(1), isNull);
    },
  );

  test(
    'replacement commits exactly one profile and its cached snapshot',
    () async {
      expect(await repository.current(), isNull);
      await repository.commit(profile: candidate(1, 1), expectedRevision: 0);
      await repository.commit(profile: candidate(2, 2), expectedRevision: 1);
      final stored = await repository.current();
      expect(stored, candidate(2, 2).copyWith(order: 0));
      expect(await db.profilesDao.query().get(), [stored]);
      expect((await repository.state()).revision, 2);
      expect((await repository.state()).profileId, 2);
      await expectLater(
        db.profiles.put(candidate(3, 3).toCompanion()),
        throwsA(isA<Exception>()),
      );
      expect(await db.profilesDao.query().get(), [stored]);
    },
  );

  test(
    'stale commits and stale metadata updates cannot overwrite a replacement',
    () async {
      await repository.commit(profile: candidate(1, 1), expectedRevision: 0);
      await repository.commit(profile: candidate(2, 2), expectedRevision: 1);
      await expectLater(
        repository.commit(profile: candidate(3, 2), expectedRevision: 1),
        throwsA(isA<StaleProfileRevision>()),
      );
      await expectLater(
        repository.update(profile: candidate(1, 1), expectedRevision: 1),
        throwsA(isA<StaleProfileRevision>()),
      );
      final profile = (await repository.current())!;
      await repository.update(
        profile: profile.copyWith(label: 'Renamed'),
        expectedRevision: 2,
      );
      expect((await repository.current())?.label, 'Renamed');
      await expectLater(
        repository.update(profile: candidate(2, 3), expectedRevision: 2),
        throwsArgumentError,
      );
    },
  );

  test(
    'database failure rolls back profile, links, groups, and durable state',
    () async {
      await repository.commit(
        profile: candidate(1, 1),
        expectedRevision: 0,
        ownedData: ProfileOwnedData(
          rules: [Rule.parse('DOMAIN,example.test,DIRECT', id: 10)],
          links: const [
            ProfileRuleLink(profileId: 1, ruleId: 10, scene: RuleScene.custom),
          ],
          groups: const [
            ProxyGroup(id: 20, name: 'Custom', type: GroupType.Selector),
          ],
        ),
      );
      final oldProfile = await repository.current();
      final oldState = await repository.state();
      await db.customStatement('''
      CREATE TRIGGER fail_commit BEFORE UPDATE ON profile_commit_state
      BEGIN SELECT RAISE(ABORT, 'simulated disk failure'); END
    ''');
      await expectLater(
        repository.commit(profile: candidate(2, 2), expectedRevision: 1),
        throwsA(isA<Exception>()),
      );
      expect(await repository.current(), oldProfile);
      expect(await repository.state(), oldState);
      expect(await db.rulesDao.queryProfileCustomRules(1).get(), hasLength(1));
      expect(await db.proxyGroupsDao.query(1).get(), hasLength(1));
      expect(await db.profilesDao.query().get(), [oldProfile]);
    },
  );

  test(
    'pruning removes only unreferenced profile data and retains shared data',
    () async {
      final shared = Rule.parse('DOMAIN,shared.test,DIRECT', id: 10);
      await db.rulesDao.putGlobalRule(shared);
      await db.scripts.put(
        Script(
          id: 50,
          label: 'Shared script',
          lastUpdateTime: DateTime(2026),
        ).toCompanion(),
      );
      await db.proxyGroups.put(
        const ProxyGroup(
          id: 60,
          name: 'Shared group',
          type: GroupType.Selector,
        ).toCompanion(),
      );
      await repository.commit(
        profile: candidate(1, 1),
        expectedRevision: 0,
        ownedData: ProfileOwnedData(
          rules: [shared, Rule.parse('DOMAIN,private.test,DIRECT', id: 11)],
          links: const [
            ProfileRuleLink(profileId: 1, ruleId: 10, scene: RuleScene.added),
            ProfileRuleLink(profileId: 1, ruleId: 11, scene: RuleScene.custom),
          ],
          groups: const [
            ProxyGroup(id: 20, name: 'Private group', type: GroupType.Selector),
          ],
        ),
      );
      await repository.commit(profile: candidate(2, 2), expectedRevision: 1);
      expect(await db.rulesDao.queryGlobalAddedRules().get(), hasLength(1));
      expect((await db.select(db.rules).get()).map((rule) => rule.id), [10]);
      expect((await db.select(db.proxyGroups).get()).map((group) => group.id), [
        60,
      ]);
      expect(await db.select(db.scripts).get(), hasLength(1));
    },
  );

  test(
    'migration cannot prune legacy rows without an archive and is durable',
    () async {
      const profiles = [
        Profile(id: 1, autoUpdateDuration: Duration.zero),
        Profile(id: 2, autoUpdateDuration: Duration.zero),
      ];
      await db.profilesDao.setAll(profiles);
      await expectLater(
        repository.commit(profile: candidate(2, 1), expectedRevision: 0),
        throwsStateError,
      );
      expect(await db.profilesDao.query().get(), hasLength(2));
      await repository.commit(
        profile: candidate(2, 1),
        expectedRevision: 0,
        migrationArchive: 'recovery/legacy.zip',
      );
      await repository.commit(profile: candidate(3, 2), expectedRevision: 1);
      expect(
        (await repository.state()).migrationArchive,
        'recovery/legacy.zip',
      );
      expect((await repository.state()).migrationVersion, 1);
      expect(await db.profilesDao.query().get(), hasLength(1));
    },
  );

  test('candidate-owned data cannot modify shared rules or groups', () async {
    await db.rulesDao.putGlobalRule(
      Rule.parse('DOMAIN,shared.test,DIRECT', id: 10),
    );
    await expectLater(
      repository.commit(
        profile: candidate(1, 1),
        expectedRevision: 0,
        ownedData: ProfileOwnedData(
          rules: [Rule.parse('DOMAIN,changed.test,REJECT', id: 10)],
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.current(), isNull);
    expect(
      (await db.rulesDao.queryGlobalAddedRules().get()).single.content,
      'shared.test',
    );
  });
}
