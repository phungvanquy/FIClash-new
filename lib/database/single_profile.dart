part of 'database.dart';

@DataClassName('ProfileCommitState')
class ProfileCommitStates extends Table {
  @override
  String get tableName => 'profile_commit_state';

  IntColumn get id => integer().check(const CustomExpression('id = 1'))();

  IntColumn get revision => integer().withDefault(const Constant(0))();

  IntColumn get profileId => integer().nullable()();

  IntColumn get migrationVersion => integer().withDefault(const Constant(0))();

  TextColumn get migrationArchive => text().nullable()();

  TextColumn get pendingRestore => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StaleProfileRevision implements Exception {
  const StaleProfileRevision();
}

class ProfileRestoreData {
  const ProfileRestoreData({
    this.settings,
    this.scripts = const [],
    this.scriptContents = const {},
    this.rules = const [],
    this.links = const [],
    this.replaceShared = false,
    this.expectedLibrary,
  });

  final Config? settings;
  final List<Script> scripts;
  final Map<int, String> scriptContents;
  final List<Rule> rules;
  final List<ProfileRuleLink> links;
  final bool replaceShared;
  final String? expectedLibrary;

  Map<String, dynamic> publication() => {
    'version': 1,
    if (settings != null) 'settings': settings!.toJson(),
    'scripts': {
      for (final entry in scriptContents.entries) '${entry.key}': entry.value,
    },
  };
}

class ProfileOwnedData {
  const ProfileOwnedData({
    this.rules = const [],
    this.links = const [],
    this.groups = const [],
  });

  final List<Rule> rules;
  final List<ProfileRuleLink> links;
  final List<ProxyGroup> groups;

  List<Rule> rulesFor(RuleScene scene) {
    final byId = {for (final rule in rules) rule.id: rule};
    final ordered = links.where((link) => link.scene == scene).toList()
      ..sort((a, b) => (a.order ?? '').compareTo(b.order ?? ''));
    return [
      for (final link in ordered)
        if (byId[link.ruleId] case final rule?)
          rule.copyWith(order: link.order),
    ];
  }
}

class SingleProfileRepository {
  SingleProfileRepository(this._db);

  final Database _db;

  Future<({String fingerprint, List<Rule> globals})> restoreLibrary() =>
      _db.transaction(() async {
        final scripts = await _db.select(_db.scripts).get();
        final rules = await _db.select(_db.rules).get();
        final links = await _db.select(_db.profileRuleLinks).get();
        final groups = await _db.select(_db.proxyGroups).get();
        return (
          fingerprint: jsonEncode([
            scripts.map((row) => jsonEncode(row.toJson())).toList()..sort(),
            rules.map((row) => jsonEncode(row.toJson())).toList()..sort(),
            links.map((row) => jsonEncode(row.toJson())).toList()..sort(),
            groups.map((row) => jsonEncode(row.toJson())).toList()..sort(),
          ]),
          globals: await _db.rulesDao.queryGlobalAddedRules().get(),
        );
      });

  Future<ProfileOwnedData> ownedData(int profileId) => _db.transaction(
    () async {
      final links =
          await (_db.select(_db.profileRuleLinks)
                ..where((row) => row.profileId.equals(profileId)))
              .map((row) => row.toLink())
              .get();
      final rules =
          await (_db.select(_db.rules)
                ..where((row) => row.id.isIn(links.map((link) => link.ruleId))))
              .map((row) => row.toRule())
              .get();
      return ProfileOwnedData(
        rules: rules,
        links: links,
        groups: await _db.proxyGroupsDao.query(profileId).get(),
      );
    },
  );

  Future<ProfileCommitState> state() async =>
      await _db.select(_db.profileCommitStates).getSingleOrNull() ??
      const ProfileCommitState(id: 1, revision: 0, migrationVersion: 0);

  Future<Profile?> current() => _db.transaction(() async {
    final committed = await state();
    if (committed.profileId == null) return null;
    final row = await (_db.select(
      _db.profiles,
    )..where((row) => row.id.equals(committed.profileId!))).getSingleOrNull();
    if (row == null || row.snapshot.revision != committed.revision) {
      throw StateError('Committed profile revision is inconsistent');
    }
    return row.toProfile();
  });

  Future<Profile?> legacy(int id) => _db.transaction(() async {
    if ((await state()).migrationVersion != 0) return null;
    final row = await (_db.select(
      _db.profiles,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    return row?.toProfile();
  });

  Future<List<Profile>> legacyProfiles() => _db.transaction(() async {
    if ((await state()).migrationVersion != 0) return [];
    return _db.profilesDao.query().get();
  });

  Future<void> recordMigrationArchive(String archive) =>
      _db.transaction(() async {
        if (archive.isEmpty) throw ArgumentError('Missing migration archive');
        final previous = await state();
        if (previous.migrationVersion != 0 || previous.revision != 0) {
          throw const StaleProfileRevision();
        }
        await _db.profileCommitStates.insertOnConflictUpdate(
          ProfileCommitStatesCompanion.insert(
            id: const Value(1),
            migrationArchive: Value(archive),
          ),
        );
      });

  Future<void> completeEmptyMigration({String? archive}) =>
      _db.transaction(() async {
        final previous = await state();
        if (previous.migrationVersion != 0 || previous.revision != 0) {
          throw const StaleProfileRevision();
        }
        final profiles = await _db.profilesDao.query().get();
        if (profiles.isNotEmpty && (archive == null || archive.isEmpty)) {
          throw StateError(
            'Legacy profiles require a verified migration archive',
          );
        }
        final ids = profiles.map((profile) => profile.id).toSet();
        final links = await (_db.select(
          _db.profileRuleLinks,
        )..where((row) => row.profileId.isIn(ids))).get();
        await (_db.delete(
          _db.profileRuleLinks,
        )..where((row) => row.profileId.isIn(ids))).go();
        await (_db.delete(
          _db.proxyGroups,
        )..where((row) => row.profileId.isIn(ids))).go();
        await (_db.delete(_db.profiles)..where((row) => row.id.isIn(ids))).go();
        final references = _db.selectOnly(_db.profileRuleLinks)
          ..addColumns([_db.profileRuleLinks.ruleId]);
        await (_db.delete(_db.rules)..where(
              (row) =>
                  row.id.isIn(links.map((link) => link.ruleId)) &
                  row.id.isNotInQuery(references),
            ))
            .go();
        await _db.profileCommitStates.insertOnConflictUpdate(
          ProfileCommitStatesCompanion.insert(
            id: const Value(1),
            migrationVersion: const Value(1),
            migrationArchive: Value(archive ?? previous.migrationArchive),
          ),
        );
      });

  Future<void> commit({
    required Profile profile,
    required int expectedRevision,
    ProfileOwnedData? ownedData,
    ProfileRestoreData? restoreData,
    String? migrationArchive,
    void Function()? checkCurrent,
  }) => _db.transaction(() async {
    checkCurrent?.call();
    final previous = await state();
    if (previous.revision != expectedRevision ||
        previous.pendingRestore != null) {
      throw const StaleProfileRevision();
    }
    if (profile.snapshot.revision != expectedRevision + 1) {
      throw ArgumentError('Candidate revision must follow committed revision');
    }
    if (profile.id <= 0 || migrationArchive == '') {
      throw ArgumentError('Invalid profile or migration archive');
    }
    final oldProfiles = await _db.profilesDao.query().get();
    if (previous.migrationVersion == 0 &&
        oldProfiles.isNotEmpty &&
        migrationArchive == null) {
      throw StateError('Legacy profiles require a verified migration archive');
    }
    if (restoreData != null) await _validateRestoreData(restoreData);
    if (ownedData != null) {
      await _validateOwnedData(
        profile.id,
        ownedData,
        available:
            restoreData?.rules.map((rule) => rule.id).toSet() ?? const {},
      );
    }

    final removedIds = oldProfiles
        .where((item) => item.id != profile.id)
        .map((item) => item.id)
        .toSet();
    final replacedIds = {...removedIds, if (ownedData != null) profile.id};
    final removedLinks = await (_db.select(
      _db.profileRuleLinks,
    )..where((row) => row.profileId.isIn(replacedIds))).get();
    await (_db.delete(
      _db.profileRuleLinks,
    )..where((row) => row.profileId.isIn(replacedIds))).go();
    await (_db.delete(
      _db.proxyGroups,
    )..where((row) => row.profileId.isIn(replacedIds))).go();
    await (_db.delete(
      _db.profiles,
    )..where((row) => row.id.isIn(removedIds))).go();
    await _db.profiles.insertOnConflictUpdate(profile.toCompanion(0));

    if (restoreData != null) {
      if (restoreData.replaceShared) {
        removedLinks.addAll(
          await (_db.select(
            _db.profileRuleLinks,
          )..where((row) => row.profileId.isNull())).get(),
        );
      }
      await _restoreShared(restoreData);
    }

    if (ownedData != null) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.rules,
          ownedData.rules.map((rule) => rule.toCompanion()),
        );
        batch.insertAllOnConflictUpdate(
          _db.profileRuleLinks,
          ownedData.links.map((link) => link.toCompanion()),
        );
        batch.insertAllOnConflictUpdate(
          _db.proxyGroups,
          ownedData.groups.map((group) => group.toCompanion(profile.id)),
        );
      });
    }
    final referencedRules = _db.selectOnly(_db.profileRuleLinks)
      ..addColumns([_db.profileRuleLinks.ruleId]);
    await (_db.delete(_db.rules)..where(
          (row) =>
              row.id.isIn(removedLinks.map((link) => link.ruleId)) &
              row.id.isNotInQuery(referencedRules),
        ))
        .go();
    await _db.profileCommitStates.insertOnConflictUpdate(
      ProfileCommitStatesCompanion.insert(
        id: const Value(1),
        revision: Value(profile.snapshot.revision),
        profileId: Value(profile.id),
        migrationVersion: const Value(1),
        migrationArchive: Value(migrationArchive ?? previous.migrationArchive),
        pendingRestore: Value(
          restoreData == null ? null : jsonEncode(restoreData.publication()),
        ),
      ),
    );
    checkCurrent?.call();
  });

  Future<void> finishRestore(
    int revision,
    String publication,
  ) => _db.transaction(() async {
    final current = await state();
    if (current.revision != revision || current.pendingRestore != publication) {
      throw const StaleProfileRevision();
    }
    await (_db.update(_db.profileCommitStates)
          ..where((row) => row.id.equals(1)))
        .write(const ProfileCommitStatesCompanion(pendingRestore: Value(null)));
  });

  Future<void> restoreWithoutProfile(
    ProfileRestoreData data, {
    void Function()? checkCurrent,
  }) => _db.transaction(() async {
    checkCurrent?.call();
    final previous = await state();
    if (previous.profileId != null ||
        previous.revision != 0 ||
        previous.pendingRestore != null ||
        (await _db.profilesDao.query().get()).isNotEmpty) {
      throw const StaleProfileRevision();
    }
    await _validateRestoreData(data);
    final oldLinks = data.replaceShared
        ? await (_db.select(
            _db.profileRuleLinks,
          )..where((row) => row.profileId.isNull())).get()
        : <RawProfileRuleLink>[];
    await _restoreShared(data);
    final references = _db.selectOnly(_db.profileRuleLinks)
      ..addColumns([_db.profileRuleLinks.ruleId]);
    await (_db.delete(_db.rules)..where(
          (row) =>
              row.id.isIn(oldLinks.map((link) => link.ruleId)) &
              row.id.isNotInQuery(references),
        ))
        .go();
    await _db.profileCommitStates.insertOnConflictUpdate(
      ProfileCommitStatesCompanion.insert(
        id: const Value(1),
        migrationVersion: const Value(1),
        migrationArchive: Value(previous.migrationArchive),
        pendingRestore: Value(jsonEncode(data.publication())),
      ),
    );
    checkCurrent?.call();
  });

  Future<void> _validateRestoreData(ProfileRestoreData data) async {
    if (data.expectedLibrary != null &&
        data.expectedLibrary != (await restoreLibrary()).fingerprint) {
      throw const StaleProfileRevision();
    }
    final ids = data.rules.map((rule) => rule.id).toSet();
    final scriptIds = data.scripts.map((script) => script.id).toSet();
    if (ids.length != data.rules.length ||
        scriptIds.length != data.scripts.length ||
        data.links.any(
          (link) => link.profileId != null || !ids.contains(link.ruleId),
        ) ||
        data.links.map((link) => link.key).toSet().length !=
            data.links.length ||
        !scriptIds.containsAll(data.scriptContents.keys) ||
        !data.scriptContents.keys.toSet().containsAll(scriptIds)) {
      throw ArgumentError('Invalid shared restore data');
    }
    final existingScripts = await (_db.select(
      _db.scripts,
    )..where((row) => row.id.isIn(scriptIds))).get();
    final existingRules = await (_db.select(
      _db.rules,
    )..where((row) => row.id.isIn(ids))).get();
    if (existingScripts.isNotEmpty || existingRules.isNotEmpty) {
      throw ArgumentError('Restore must allocate new shared record identities');
    }
  }

  Future<void> _restoreShared(ProfileRestoreData data) => _db.batch((batch) {
    if (data.replaceShared) {
      batch.deleteWhere(_db.profileRuleLinks, (row) => row.profileId.isNull());
      batch.deleteWhere(_db.scripts, (row) => const Constant(true));
    }
    batch.insertAll(
      _db.scripts,
      data.scripts.map((script) => script.toCompanion()),
    );
    batch.insertAll(_db.rules, data.rules.map((rule) => rule.toCompanion()));
    batch.insertAll(
      _db.profileRuleLinks,
      data.links.map((link) => link.toCompanion()),
    );
  });

  Future<void> update({
    required int expectedRevision,
    required Profile profile,
    void Function()? checkCurrent,
  }) => _db.transaction(() async {
    checkCurrent?.call();
    if ((await state()).pendingRestore != null) {
      throw const StaleProfileRevision();
    }
    final committed = await current();
    if (committed == null ||
        committed.id != profile.id ||
        committed.snapshot.revision != expectedRevision) {
      throw const StaleProfileRevision();
    }
    if (profile.snapshot.revision != expectedRevision ||
        profile.snapshot.generation != committed.snapshot.generation) {
      throw ArgumentError('Metadata updates cannot replace profile content');
    }
    await _db.profiles.insertOnConflictUpdate(profile.toCompanion(0));
    checkCurrent?.call();
  });

  Future<void> _validateOwnedData(
    int profileId,
    ProfileOwnedData data, {
    Set<int> available = const {},
  }) async {
    final ruleIds = data.rules.map((rule) => rule.id).toSet();
    if (ruleIds.length != data.rules.length ||
        data.groups.map((group) => group.id).toSet().length !=
            data.groups.length ||
        data.links.map((link) => link.key).toSet().length !=
            data.links.length) {
      throw ArgumentError('Candidate contains duplicate owned records');
    }
    if (data.links.any((link) => link.profileId != profileId) ||
        data.groups.any(
          (group) => group.profileId != null && group.profileId != profileId,
        )) {
      throw ArgumentError('Candidate data belongs to another profile');
    }
    final existingRules =
        await (_db.select(_db.rules)..where(
              (row) => row.id.isIn(data.links.map((link) => link.ruleId)),
            ))
            .get();
    final availableRules = {
      ...available,
      ...ruleIds,
      ...existingRules.map((rule) => rule.id),
    };
    if (data.links.any((link) => !availableRules.contains(link.ruleId))) {
      throw ArgumentError('Candidate links to a missing rule');
    }
    final sharedIds = _db.selectOnly(_db.profileRuleLinks)
      ..addColumns([_db.profileRuleLinks.ruleId])
      ..where(
        _db.profileRuleLinks.profileId.isNull() |
            _db.profileRuleLinks.profileId.equals(profileId).not(),
      );
    final conflicts =
        await (_db.select(_db.rules)..where(
              (row) =>
                  row.id.isIn(data.rules.map((rule) => rule.id)) &
                  row.id.isInQuery(sharedIds),
            ))
            .get();
    for (final existing in conflicts) {
      final candidate = data.rules.firstWhere((rule) => rule.id == existing.id);
      if (existing.toRule() != candidate.copyWith(order: null)) {
        throw ArgumentError('Candidate would overwrite a shared rule');
      }
    }
    final existingGroups = await (_db.select(
      _db.proxyGroups,
    )..where((row) => row.id.isIn(data.groups.map((group) => group.id)))).get();
    if (existingGroups.any((group) => group.profileId != profileId)) {
      throw ArgumentError('Candidate would overwrite a shared proxy group');
    }
  }
}
