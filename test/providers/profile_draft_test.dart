import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

class _Action extends VpnAction {
  Profile? submitted;
  Profile? expectedProfile;
  db.ProfileOwnedData? submittedData;
  Completer<VpnImportResult>? gate;
  int cancellations = 0;

  @override
  Future<VpnImportResult> edit(
    Profile profile, {
    List<int>? bytes,
    Profile? expected,
    db.ProfileOwnedData? ownedData,
  }) async {
    submitted = profile;
    expectedProfile = expected;
    submittedData = ownedData;
    return await gate?.future ?? const VpnImportResult(VpnImportOutcome.failed);
  }

  @override
  void cancelIfCurrent(int revision) => cancellations++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = Profile(
    id: 1,
    label: 'Current',
    autoUpdateDuration: Duration(hours: 1),
    order: 0,
    snapshot: ProfileSnapshot(
      revision: 1,
      generation: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  );
  const added = Rule(id: 10, content: 'example.com', ruleTarget: 'A');
  const custom = Rule(id: 11, ruleAction: RuleAction.MATCH, ruleTarget: 'A');
  const global = Rule(id: 12, content: 'global.example', ruleTarget: 'DIRECT');
  const group = ProxyGroup(
    id: 20,
    profileId: 1,
    name: 'A',
    type: GroupType.Selector,
    proxies: ['DIRECT'],
    order: 'a0',
  );
  const initial = db.ProfileOwnedData(
    rules: [added, custom],
    links: [
      ProfileRuleLink(
        profileId: 1,
        ruleId: 10,
        scene: RuleScene.added,
        order: 'a0',
      ),
      ProfileRuleLink(
        profileId: 1,
        ruleId: 11,
        scene: RuleScene.custom,
        order: 'a0',
      ),
    ],
    groups: [group],
  );
  late db.Database database;
  late ProviderContainer container;
  late ProfileDraft draft;
  late _Action action;

  setUp(() async {
    database = db.Database(NativeDatabase.memory());
    db.database = database;
    await database.singleProfile.commit(
      profile: profile,
      expectedRevision: 0,
      ownedData: initial,
    );
    await database.rulesDao.putGlobalRule(global);
    container = ProviderContainer(
      overrides: [
        singleProfileRepositoryProvider.overrideWithValue(
          database.singleProfile,
        ),
        vpnActionProvider.overrideWith(_Action.new),
      ],
    );
    container.read(profilesProvider.notifier).publishCommitted(profile);
    container.listen(profileDraftProvider(1), (_, _) {});
    draft = container.read(profileDraftProvider(1).notifier);
    action = container.read(vpnActionProvider.notifier) as _Action;
    await draft.open();
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('editing profile fields and rules changes only the draft', () async {
    draft.updateProfile(
      (value) =>
          value.copyWith(overwriteType: OverwriteType.custom, scriptId: 42),
    );
    container
        .read(profileAddedRulesProvider(1).notifier)
        .put(added.copyWith(content: 'draft.example'));
    container.read(profileDisabledRuleIdsProvider(1).notifier).put(global.id);
    expect(
      container.read(editableProfileProvider(1))?.overwriteType,
      OverwriteType.custom,
    );
    expect(container.read(profileProvider(1)), profile);
    expect(await database.singleProfile.current(), profile);
    expect((await database.singleProfile.ownedData(1)).rules, initial.rules);
    final data = container.read(profileDraftProvider(1))!.ownedData;
    expect(data.rulesFor(RuleScene.added).single.content, 'draft.example');
    expect(
      data.links.any(
        (link) => link.ruleId == global.id && link.scene == RuleScene.disabled,
      ),
      isTrue,
    );
  });

  test(
    'explicit Save rebuilds even when only shared libraries changed',
    () async {
      expect(container.read(profileDraftProvider(1))!.dirty, isFalse);
      await draft.save();
      expect(action.submitted, profile);
      expect(action.submittedData?.rules, initial.rules);
    },
  );

  test(
    'group rename updates draft references without touching persisted rules',
    () async {
      draft.putGroup(group.copyWith(id: 21, name: 'B', proxies: ['A']));
      expect(draft.putGroup(group.copyWith(name: 'B')), isFalse);
      expect(draft.putGroup(group.copyWith(name: 'Renamed')), isTrue);
      final data = container.read(profileDraftProvider(1))!.ownedData;
      expect(data.rulesFor(RuleScene.custom).single.ruleTarget, 'Renamed');
      expect(data.rulesFor(RuleScene.added).single.ruleTarget, 'A');
      expect(data.groups.last.proxies, ['Renamed']);
      expect((await database.singleProfile.ownedData(1)).groups, [group]);
    },
  );

  test(
    'deletion and reordering remain local and discard reloads persisted data',
    () async {
      draft.putRule(
        RuleScene.added,
        added.copyWith(id: 13, content: 'second.example'),
      );
      draft.orderRules(RuleScene.added, 0, 1);
      draft.deleteRules(RuleScene.custom, [custom.id]);
      draft.deleteGroup('A');
      expect(
        container
            .read(profileDraftProvider(1))!
            .ownedData
            .rulesFor(RuleScene.added)
            .last
            .id,
        13,
      );
      await draft.open();
      expect(container.read(profileDraftProvider(1))!.dirty, isFalse);
      expect(
        container.read(profileDraftProvider(1))!.ownedData.groups,
        initial.groups,
      );
      expect(
        container
            .read(profileDraftProvider(1))!
            .ownedData
            .rulesFor(RuleScene.custom)
            .single
            .id,
        custom.id,
      );
    },
  );

  test(
    'Save freezes the candidate and failed preparation retains the editable draft',
    () async {
      draft.updateProfile((value) => value.copyWith(matchTarget: 'A'));
      action.gate = Completer<VpnImportResult>();
      final saving = draft.save();
      expect(container.read(profileDraftProvider(1))!.saving, isTrue);
      draft.updateProfile((value) => value.copyWith(matchTarget: 'B'));
      expect(action.submitted?.matchTarget, 'A');
      expect(action.expectedProfile, profile);
      expect(action.submittedData?.groups, initial.groups);
      expect(await database.singleProfile.current(), profile);
      action.gate!.complete(const VpnImportResult(VpnImportOutcome.failed));
      expect((await saving).outcome, VpnImportOutcome.failed);
      expect(container.read(profileDraftProvider(1))!.saving, isFalse);
      expect(container.read(profileDraftProvider(1))!.dirty, isTrue);
      expect(container.read(profileDraftProvider(1))!.profile.matchTarget, 'A');
    },
  );

  test('successful Save adopts the committed revision', () async {
    draft.updateProfile((value) => value.copyWith(matchTarget: 'A'));
    final committed = profile
        .copyWith(matchTarget: 'A')
        .copyWith
        .snapshot(revision: 2, generation: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    action.gate = Completer<VpnImportResult>()
      ..complete(VpnImportResult(VpnImportOutcome.success, profile: committed));
    expect((await draft.save()).profile, committed);
    expect(container.read(profileDraftProvider(1))!.original, committed);
    expect(container.read(profileDraftProvider(1))!.dirty, isFalse);
  });

  test('disposing a saving editor cancels only its own request', () async {
    draft.updateProfile((value) => value.copyWith(matchTarget: 'A'));
    action.gate = Completer<VpnImportResult>();
    final saving = draft.save();
    container.invalidate(profileDraftProvider(1));
    await container.pump();
    expect(action.cancellations, 1);
    action.gate!.complete(const VpnImportResult(VpnImportOutcome.cancelled));
    await saving;
    expect(await database.singleProfile.current(), profile);
  });

  test(
    'candidate setup combines draft rules with enabled global rules',
    () async {
      draft.setDisabled(global.id, true);
      draft.putRule(RuleScene.added, added.copyWith(content: 'draft.example'));
      final setup = await loadProfileSetupState(
        profile,
        dns: const Dns(),
        overrideDns: false,
        ownedData: container.read(profileDraftProvider(1))!.ownedData,
      );
      expect(setup.addedRules.map((rule) => rule.content), ['draft.example']);
      expect(
        (await database.rulesDao.queryAddedRules(1).get()).map(
          (rule) => rule.content,
        ),
        ['example.com', 'global.example'],
      );
    },
  );

  test('managed rules reject direct writes outside an editor', () async {
    container.invalidate(profileDraftProvider(1));
    await container.pump();
    expect(
      () => container.read(profileAddedRulesProvider(1).notifier).put(added),
      throwsStateError,
    );
    expect(await database.singleProfile.current(), profile);
  });
}
