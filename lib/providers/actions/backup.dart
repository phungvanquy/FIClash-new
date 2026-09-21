part of '../action.dart';

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<bool> consumeBackup(Future<bool> Function(String path) send) async {
    final path = await backup();
    if (path.isEmpty) {
      return false;
    }
    try {
      return await send(path);
    } finally {
      await File(path).safeDelete();
    }
  }

  @visibleForTesting
  Future<String> backup() async {
    await ref.read(vpnActionProvider.notifier).repairPendingRestore();
    return ref.read(setupActionProvider.notifier).serializeProfileCommit(
      () async {
        final store = await ref.read(profileGenerationStoreProvider.future);
        final config = ref.read(configProvider);
        final configMap = config.toJson();
        final repository = ref.read(singleProfileRepositoryProvider);
        final library = await repository.restoreLibrary();
        final version = await preferences.getVersion();
        configMap['version'] = version > 0 ? version : 1;
        final archive = await VpnArchiveStore(store.home).create(
          settings: configMap,
          snapshotDatabase: (path) =>
              database.customStatement('VACUUM INTO ?', [path]),
        );
        try {
          if ((await repository.restoreLibrary()).fingerprint !=
                  library.fingerprint ||
              ref.read(configProvider) != config) {
            throw const VpnImportCancelled();
          }
          return (await archive.copy(
            '${await appPath.tempPath}/flclash-backup-$uniqueId.zip',
          )).path;
        } finally {
          await archive.delete();
        }
      },
    );
  }

  Future<void> restore(RestoreOption option) async {
    final action = ref.read(vpnActionProvider.notifier);
    action.cancel();
    final intent = action.requestRevision;
    final restoreDir = await Directory(
      await appPath.tempPath,
    ).createTemp('vpn-restore-');
    try {
      final archive = await File(
        await appPath.backupFilePath,
      ).copy('${restoreDir.path}/backup.zip');
      final migrationData = await restoreTask(
        backupFilePath: archive.path,
        restoreDirPath: '${restoreDir.path}/content',
      );
      await applyRestore(migrationData, option, intent: intent);
    } finally {
      await restoreDir.safeDelete(recursive: true);
    }
  }

  @visibleForTesting
  Future<void> applyRestore(
    MigrationData data,
    RestoreOption option, {
    int? intent,
  }) async {
    final action = ref.read(vpnActionProvider.notifier);
    if (intent == null) action.cancel();
    final requestIntent = intent ?? action.requestRevision;
    if (requestIntent != action.requestRevision) {
      throw const VpnImportCancelled();
    }
    final initialSettings = ref.read(configProvider);
    final settings = option == RestoreOption.all && data.configMap != null
        ? Config.fromJson(data.configMap!)
        : null;
    final effectiveSettings = settings ?? initialSettings;
    final replaceShared =
        initialSettings.appSettingProps.restoreStrategy ==
        RestoreStrategy.override;
    final repository = ref.read(singleProfileRepositoryProvider);
    final current = await repository.current();
    final library = await repository.restoreLibrary();
    final store = await ref.read(profileGenerationStoreProvider.future);
    final sourceStore = data.sourcePath == null
        ? null
        : ProfileGenerationStore(Directory(data.sourcePath!));
    void checkCurrent() {
      if (!ref.mounted ||
          action.requestRevision != requestIntent ||
          ref.read(configProvider) != initialSettings) {
        throw const VpnImportCancelled();
      }
    }

    if (data.profiles.map((profile) => profile.id).toSet().length !=
            data.profiles.length ||
        data.scripts.map((script) => script.id).toSet().length !=
            data.scripts.length ||
        data.rules.map((rule) => rule.id).toSet().length != data.rules.length) {
      throw const FormatException('Duplicate restored record identity');
    }
    final scriptIds = {
      for (final script in data.scripts) script.id: snowflake.id,
    };
    final scripts = [
      for (final script in data.scripts)
        script.copyWith(id: scriptIds[script.id]!),
    ];
    final scriptContents = <int, String>{};
    for (final script in data.scripts) {
      if (sourceStore == null) {
        throw const FormatException('Missing restore resources');
      }
      final file = File('${sourceStore.home.path}/scripts/${script.id}.js');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const FormatException('Missing restored script');
      }
      scriptContents[scriptIds[script.id]!] = await file.readAsString();
      checkCurrent();
    }
    final ruleIds = {for (final rule in data.rules) rule.id: snowflake.id};
    final rules = {
      for (final rule in data.rules)
        rule.id: rule.copyWith(id: ruleIds[rule.id]!),
    };
    if (data.links.any((link) => !ruleIds.containsKey(link.ruleId))) {
      throw const FormatException('Restored rule link is missing its rule');
    }
    final globalLinks = [
      for (final link in data.links.where((link) => link.profileId == null))
        link.copyWith(ruleId: ruleIds[link.ruleId]!),
    ];
    final globalIds = globalLinks.map((link) => link.ruleId).toSet();
    final globals = rules.values
        .where((rule) => globalIds.contains(rule.id))
        .toList();
    final restoredGlobals = ProfileOwnedData(
      rules: globals,
      links: globalLinks
          .map((link) => link.copyWith(scene: RuleScene.added))
          .toList(),
    ).rulesFor(RuleScene.added);
    final effectiveGlobals = [
      if (!replaceShared) ...library.globals,
      ...restoredGlobals,
    ];
    final selectedId = data.configMap?['currentProfileId'] as int?;
    final ordered = data.profiles.toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    final selected = ordered
        .where((profile) => profile.id == selectedId)
        .firstOrNull;
    final candidates = [
      ?selected,
      ...ordered.where((profile) => profile.id != selected?.id),
      if (ordered.isEmpty && current != null) current,
    ];
    ProfileRestoreData extras() => ProfileRestoreData(
      settings: settings,
      scripts: scripts,
      scriptContents: scriptContents,
      rules: globals,
      links: globalLinks,
      replaceShared: replaceShared,
      expectedLibrary: library.fingerprint,
    );
    if (candidates.isEmpty) {
      await ref
          .read(setupActionProvider.notifier)
          .serializeProfileCommit(
            () => repository.restoreWithoutProfile(
              extras(),
              checkCurrent: checkCurrent,
            ),
          );
      try {
        await action.repairPendingRestore();
      } catch (_) {
        ref.read(vpnFailureProvider.notifier).value = 'recovery_required';
      }
      return;
    }
    for (final original in candidates) {
      checkCurrent();
      final retaining = data.profiles.isEmpty;
      final resources = retaining ? store : sourceStore;
      if (resources == null) {
        throw const FormatException('Missing restore resources');
      }
      final List<int> bytes;
      try {
        bytes = await (await resources.source(original)).readAsBytes();
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
      final id = retaining ? original.id : snowflake.id;
      var scriptId = scriptIds[original.scriptId];
      if (retaining && original.scriptId != null) {
        final originalScript = await database.scriptsDao
            .get(original.scriptId!)
            .getSingleOrNull();
        if (originalScript == null) {
          throw const FormatException('Selected script is unavailable');
        }
        final content = await originalScript.content;
        if (content == null) {
          throw const FormatException('Selected script content is unavailable');
        }
        scriptId = snowflake.id;
        scripts.add(originalScript.copyWith(id: scriptId));
        scriptContents[scriptId] = content;
      } else if (original.scriptId != null && scriptId == null) {
        continue;
      }
      final links = [
        for (final link in data.links.where(
          (link) => link.profileId == original.id,
        ))
          link.copyWith(profileId: id, ruleId: ruleIds[link.ruleId]!),
      ];
      final ownIds = links.map((link) => link.ruleId).toSet();
      final owned = retaining
          ? await repository.ownedData(original.id)
          : ProfileOwnedData(
              rules: rules.values
                  .where((rule) => ownIds.contains(rule.id))
                  .toList(),
              links: links,
              groups: [
                for (final group in data.proxyGroups.where(
                  (group) => group.profileId == original.id,
                ))
                  group.copyWith(id: snowflake.id, profileId: id),
              ],
            );
      final candidate = original
          .copyWith(id: id, scriptId: scriptId, order: 0)
          .copyWith
          .snapshot(
            routing: original.snapshot.generation == null
                ? VpnRoutingMode.simple
                : original.snapshot.routing,
            advancedMode: original.snapshot.generation == null
                ? effectiveSettings.patchClashConfig.mode
                : original.snapshot.advancedMode,
          );
      try {
        final decoded = loadYaml(utf8.decode(bytes));
        if (decoded is! Map) {
          throw const FormatException('Configuration must be a mapping');
        }
        final source = jsonDecode(jsonEncode(decoded)) as Map<String, dynamic>;
        final effective = await action.prepareRestoreSource(
          profile: candidate,
          source: source,
          ownedData: owned,
          settings: effectiveSettings,
          globalRules: effectiveGlobals,
          script: scripts.where((script) => script.id == scriptId).firstOrNull,
          scriptContent: scriptContents[scriptId],
        );
        final geo = <String, List<int>>{};
        for (final name in VpnCandidateStager.geoResources.keys) {
          var file = File('${resources.home.path}/$name');
          if (original.snapshot.generation != null) {
            final staged = resources.resource(
              original.snapshot.generation!,
              name,
            );
            if (await staged.exists()) file = staged;
          }
          if (await FileSystemEntity.type(file.path, followLinks: false) ==
              FileSystemEntityType.file) {
            geo[name] = await file.readAsBytes();
          }
        }
        checkCurrent();
        final result = await action.submitPreparedRestore(
          VpnImportRequest(
            profile: candidate,
            bytes: bytes,
            ownedData: owned,
            restoreData: extras(),
            effectiveSource: effective,
            testUrl: effectiveSettings.appSettingProps.testUrl,
            resources: geo,
            localOnly: true,
            recordFetchTime: false,
            migrateSelection: original.snapshot.generation == null,
            expectedProfile: current,
            checkCurrent: checkCurrent,
            localResource: (section, name, definition) => VpnProfileResources(
              resources,
            ).provider(original, section, name, definition),
          ),
          requestIntent,
        );
        if (result.outcome == VpnImportOutcome.success) return;
        if (result.outcome == VpnImportOutcome.failed &&
            result.phase == VpnImportPhase.preparation &&
            (result.error is FormatException ||
                result.error is VpnLocalResourceUnavailable ||
                result.error is CoreMethodException &&
                    (result.error as CoreMethodException).code ==
                        'prepare_failed')) {
          continue;
        }
        action.requireSuccess(result);
      } on FormatException {
        continue;
      }
    }
    throw MessageException(currentAppLocalizations.vpnImportFailed);
  }
}
