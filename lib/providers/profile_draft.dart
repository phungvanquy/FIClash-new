part of 'database.dart';

ProfileDraft? _profileEditor(Ref ref, int profileId) {
  if (ref.read(profileDraftProvider(profileId)) != null) {
    return ref.read(profileDraftProvider(profileId).notifier);
  }
  if (ref.read(profileProvider(profileId))?.snapshot.generation != null) {
    throw StateError('Snapshot overrides require an edit draft');
  }
  return null;
}

class ProfileEditDraft {
  const ProfileEditDraft({
    required this.original,
    required this.profile,
    required this.ownedData,
    this.dirty = false,
    this.saving = false,
  });

  final Profile original;
  final Profile profile;
  final ProfileOwnedData ownedData;
  final bool dirty;
  final bool saving;
}

@riverpod
Profile? editableProfile(Ref ref, int profileId) =>
    ref.watch(profileDraftProvider(profileId))?.profile ??
    ref.watch(profileProvider(profileId));

@riverpod
class ProfileDraft extends _$ProfileDraft {
  int _intent = 0;

  @override
  ProfileEditDraft? build(int profileId) => null;

  Future<void> open() async {
    if (state?.saving == true) return;
    final intent = ++_intent;
    final original = ref.read(profileProvider(profileId));
    if (original == null) throw const StaleProfileRevision();
    final ownedData = await ref
        .read(singleProfileRepositoryProvider)
        .ownedData(profileId);
    if (!ref.mounted || intent != _intent) return;
    if (ref.read(profileProvider(profileId)) != original) {
      throw const StaleProfileRevision();
    }
    state = ProfileEditDraft(
      original: original,
      profile: original,
      ownedData: ownedData,
    );
  }

  void _change({Profile? profile, ProfileOwnedData? ownedData}) {
    final draft = state;
    if (draft == null || draft.saving) return;
    state = ProfileEditDraft(
      original: draft.original,
      profile: profile ?? draft.profile,
      ownedData: ownedData ?? draft.ownedData,
      dirty: true,
    );
  }

  void updateProfile(Profile Function(Profile) update) {
    final draft = state;
    if (draft == null) return;
    _change(profile: update(draft.profile));
  }

  void replaceRules(RuleScene scene, List<Rule> rules) {
    final draft = state;
    if (draft == null) return;
    final data = draft.ownedData;
    final links = [
      ...data.links.where((link) => link.scene != scene),
      for (final rule in rules)
        ProfileRuleLink(
          profileId: profileId,
          ruleId: rule.id,
          scene: scene,
          order: rule.order,
        ),
    ];
    final ids = links.map((link) => link.ruleId).toSet();
    final registry = {
      for (final rule in [...data.rules, ...rules]) rule.id: rule,
    };
    _change(
      ownedData: ProfileOwnedData(
        rules: registry.values.where((rule) => ids.contains(rule.id)).toList(),
        links: links,
        groups: data.groups,
      ),
    );
  }

  void putRule(RuleScene scene, Rule rule) {
    final rules = state!.ownedData.rulesFor(scene);
    final next = rule.autoOrder(rule, null, rules.firstOrNull?.order);
    replaceRules(scene, rules.copyAndPut(next, (item) => item.id == next.id));
  }

  void deleteRules(RuleScene scene, Iterable<int> ids) => replaceRules(
    scene,
    state!.ownedData
        .rulesFor(scene)
        .where((rule) => !ids.contains(rule.id))
        .toList(),
  );

  void orderRules(RuleScene scene, int oldIndex, int newIndex) {
    final rules = state!.ownedData
        .rulesFor(scene)
        .copyAndReorder(oldIndex, newIndex);
    final order = indexing.generateKeyBetween(
      rules.safeGet(newIndex - 1)?.order,
      rules.safeGet(newIndex + 1)?.order,
    );
    rules[newIndex] = rules[newIndex].copyWith(order: order);
    replaceRules(scene, rules);
  }

  void setDisabled(int ruleId, bool disabled) {
    final data = state!.ownedData;
    final links = data.links
        .where(
          (link) => link.ruleId != ruleId || link.scene != RuleScene.disabled,
        )
        .toList();
    if (disabled) {
      links.add(
        ProfileRuleLink(
          profileId: profileId,
          ruleId: ruleId,
          scene: RuleScene.disabled,
        ),
      );
    }
    _change(
      ownedData: ProfileOwnedData(
        rules: data.rules,
        links: links,
        groups: data.groups,
      ),
    );
  }

  void replaceGroups(List<ProxyGroup> groups) {
    final data = state!.ownedData;
    final ordered = List<ProxyGroup>.from(groups)
      ..sort((a, b) => (a.order ?? '').compareTo(b.order ?? ''));
    _change(
      ownedData: ProfileOwnedData(
        rules: data.rules,
        links: data.links,
        groups: ordered,
      ),
    );
  }

  bool putGroup(ProxyGroup group) {
    final data = state!.ownedData;
    if (data.groups.any(
      (item) => item.id != group.id && item.name == group.name,
    )) {
      return false;
    }
    final previous = data.groups.firstWhereOrNull(
      (item) => item.id == group.id,
    );
    final next = group.copyWith(
      profileId: profileId,
      order:
          previous?.order ??
          indexing.generateKeyBetween(data.groups.lastOrNull?.order, null),
    );
    var groups = data.groups.copyAndPut(next, (item) => item.id == next.id);
    if (previous != null && previous.name != next.name) {
      groups = groups
          .map(
            (item) => item.copyWith(
              proxies: item.proxies
                  ?.map((name) => name == previous.name ? next.name : name)
                  .toList(),
            ),
          )
          .toList();
      replaceRules(
        RuleScene.custom,
        data
            .rulesFor(RuleScene.custom)
            .map(
              (rule) => rule.ruleTarget == previous.name
                  ? rule.copyWith(ruleTarget: next.name)
                  : rule,
            )
            .toList(),
      );
    }
    replaceGroups(groups);
    return true;
  }

  void deleteGroup(String name) => replaceGroups(
    state!.ownedData.groups.where((group) => group.name != name).toList(),
  );

  void orderGroups(int oldIndex, int newIndex) {
    final groups = state!.ownedData.groups.copyAndReorder(oldIndex, newIndex);
    groups[newIndex] = groups[newIndex].copyWith(
      order: indexing.generateKeyBetween(
        groups.safeGet(newIndex - 1)?.order,
        groups.safeGet(newIndex + 1)?.order,
      ),
    );
    replaceGroups(groups);
  }

  void useDefaults(ClashConfig config) {
    final ruleOrders = indexing.generateNKeys(config.rules.length);
    replaceRules(
      RuleScene.custom,
      config.rules
          .mapIndexed(
            (index, rule) =>
                rule.copyWith(id: snowflake.id, order: ruleOrders[index]),
          )
          .toList(),
    );
    final groupOrders = indexing.generateNKeys(config.proxyGroups.length);
    replaceGroups(
      config.proxyGroups
          .mapIndexed(
            (index, group) => group.copyWith(
              id: snowflake.id,
              profileId: profileId,
              order: groupOrders[index],
            ),
          )
          .toList(),
    );
  }

  Future<VpnImportResult> save() async {
    final draft = state;
    if (draft == null || draft.saving) {
      return const VpnImportResult(VpnImportOutcome.cancelled);
    }
    state = ProfileEditDraft(
      original: draft.original,
      profile: draft.profile,
      ownedData: draft.ownedData,
      dirty: true,
      saving: true,
    );
    final action = ref.read(vpnActionProvider.notifier);
    final operation = action.edit(
      draft.profile,
      expected: draft.original,
      ownedData: draft.ownedData,
    );
    final requestRevision = action.requestRevision;
    var completed = false;
    ref.onDispose(() {
      if (!completed) action.cancelIfCurrent(requestRevision);
    });
    try {
      final result = await operation;
      if (ref.mounted && result.outcome == VpnImportOutcome.success) {
        final profile = result.profile!;
        state = ProfileEditDraft(
          original: profile,
          profile: profile,
          ownedData: draft.ownedData,
        );
      }
      return result;
    } finally {
      completed = true;
      if (ref.mounted && state?.saving == true) state = draft;
    }
  }
}
