part of '../state.dart';

@riverpod
ProfilesState profilesState(Ref ref) {
  final currentProfileId = ref.watch(currentProfileIdProvider);
  final profiles = ref.watch(profilesProvider);
  return ProfilesState(profiles: profiles, currentProfileId: currentProfileId);
}

@riverpod
Profile? currentProfile(Ref ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
Profile? profile(Ref ref, int? profileId) {
  return ref.watch(
    profilesProvider.select((state) => state.getProfile(profileId)),
  );
}

@riverpod
OverwriteType overwriteType(Ref ref, int? profileId) {
  if (profileId == null) return OverwriteType.standard;
  return ref.watch(
    editableProfileProvider(
      profileId,
    ).select((state) => state?.overwriteType ?? OverwriteType.standard),
  );
}

@riverpod
Future<ClashConfig> clashConfig(Ref ref, int profileId) async {
  final generation = ref.watch(profileProvider(profileId))?.snapshot.generation;
  final configMap = await ref
      .read(coreHandlerProvider)
      .getConfig(profileId, generation: generation);
  return clashConfigTask(configMap);
}

@riverpod
Future<SetupState> setupState(Ref ref, int? profileId) async {
  final profile = ref.watch(profileProvider(profileId));
  final dns = ref.watch(patchClashConfigProvider.select((state) => state.dns));
  final overrideDns = ref.watch(overrideDnsProvider);
  return loadProfileSetupState(profile, dns: dns, overrideDns: overrideDns);
}

Future<SetupState> loadProfileSetupState(
  Profile? profile, {
  required Dns dns,
  required bool overrideDns,
  ProfileOwnedData? ownedData,
  List<Rule>? globalRules,
  Script? scriptOverride,
}) async {
  final profileId = profile?.id;
  final scriptId = profile?.scriptId;
  final profileLastUpdateDate = profile?.lastUpdateDate?.millisecondsSinceEpoch;
  final overwriteType = profile?.overwriteType ?? OverwriteType.standard;
  List<ProxyGroup> proxyGroups = [];
  List<Rule> rules = [];
  List<Rule> addedRules = [];
  Script? script;
  if (profileId != null) {
    if (overwriteType == OverwriteType.standard) {
      if (ownedData == null) {
        addedRules = await database.rulesDao.queryAddedRules(profileId).get();
      } else {
        final disabled = ownedData.links
            .where((link) => link.scene == RuleScene.disabled)
            .map((link) => link.ruleId)
            .toSet();
        addedRules = [
          ...ownedData.rulesFor(RuleScene.added),
          ...globalRules ??
              await database.rulesDao.queryGlobalAddedRules().get(),
        ].where((rule) => !disabled.contains(rule.id)).toList();
      }
    } else if (overwriteType == OverwriteType.script) {
      script =
          scriptOverride ??
          (scriptId == null
              ? null
              : await database.scriptsDao.get(scriptId).getSingleOrNull());
      if (scriptId != null && script == null) {
        throw const FormatException('Selected override script is unavailable');
      }
    } else {
      rules =
          ownedData?.rulesFor(RuleScene.custom) ??
          await database.rulesDao.queryProfileCustomRules(profileId).get();
      proxyGroups =
          ownedData?.groups ??
          await database.proxyGroupsDao.query(profileId).get();
    }
  }
  return SetupState(
    rules: rules,
    proxyGroups: proxyGroups,
    profileId: profileId,
    profileLastUpdateDate: profileLastUpdateDate,
    overwriteType: overwriteType,
    addedRules: addedRules,
    script: script,
    overrideDns: overrideDns,
    dns: dns,
    matchTarget: overwriteType == OverwriteType.standard
        ? profile?.matchTarget
        : null,
  );
}
