import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Draft extends ProfileDraft {
  @override
  Future<void> open() async {
    final profile = ref.read(profileProvider(profileId))!;
    state = ProfileEditDraft(
      original: profile,
      profile: profile,
      ownedData: const db.ProfileOwnedData(),
    );
  }
}

class _Action extends VpnAction {
  int saves = 0;
  Completer<VpnImportResult>? gate;

  @override
  Future<VpnImportResult> edit(
    Profile profile, {
    List<int>? bytes,
    Profile? expected,
    db.ProfileOwnedData? ownedData,
  }) async {
    saves++;
    return await gate?.future ?? const VpnImportResult(VpnImportOutcome.failed);
  }
}

class _Setup extends SetupAction {
  int applies = 0;

  @override
  void autoApplyProfile() => applies++;
}

void main() {
  late ProviderContainer container;
  late Profile profile;

  setUp(() {
    profile = Profile.normal().copyWith(overwriteType: OverwriteType.custom);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        profileDraftProvider.overrideWith2((_) => _Draft()),
        clashConfigProvider(
          profile.id,
        ).overrideWithValue(const AsyncData(ClashConfig())),
        vpnActionProvider.overrideWith(_Action.new),
        setupActionProvider.overrideWith(_Setup.new),
      ],
    );
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = const Size(1200, 900);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => BaseNavigator.push(
                context,
                OverwriteView(profileId: profile.id),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  testWidgets(
    'leaving the editor discards changes without applying the profile',
    (tester) async {
      await pump(tester);
      container
          .read(profileDraftProvider(profile.id).notifier)
          .updateProfile((value) => value.copyWith(matchTarget: 'DIRECT'));
      await tester.pump();
      expect(find.textContaining('drafts until you save'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OverwriteView), findsNothing);
      expect(container.read(profileProvider(profile.id)), profile);
      expect((container.read(vpnActionProvider.notifier) as _Action).saves, 0);
      expect(
        (container.read(setupActionProvider.notifier) as _Setup).applies,
        0,
      );
      await close(tester);
    },
  );

  testWidgets('failed Save keeps the draft visible and permits retry', (
    tester,
  ) async {
    await pump(tester);
    final editor = container.read(profileDraftProvider(profile.id).notifier);
    editor.updateProfile((value) => value.copyWith(matchTarget: 'DIRECT'));
    final action = container.read(vpnActionProvider.notifier) as _Action;
    action.gate = Completer<VpnImportResult>();
    final save = find.byKey(const Key('vpn-save-overrides'));
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(container.read(profileProvider(profile.id)), profile);
    action.gate!.complete(const VpnImportResult(VpnImportOutcome.failed));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save this draft'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(
      container.read(profileDraftProvider(profile.id))?.profile.matchTarget,
      'DIRECT',
    );
    action.gate = Completer<VpnImportResult>()
      ..complete(VpnImportResult(VpnImportOutcome.success, profile: profile));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.byType(OverwriteView), findsNothing);
    expect(action.saves, 2);
    await close(tester);
  });
}
