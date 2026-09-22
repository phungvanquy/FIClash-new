import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/vpn_configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Action extends VpnAction {
  int calls = 0;
  int cancellations = 0;
  late final gate = Completer<VpnImportResult>();
  VpnProgressCallback? progress;

  @override
  Future<VpnImportResult> refresh(
    Profile profile, {
    void Function()? checkCurrent,
    VpnProgressCallback? onProgress,
  }) {
    calls++;
    progress = onProgress;
    return gate.future;
  }

  @override
  Future<VpnImportResult> edit(
    Profile profile, {
    List<int>? bytes,
    Profile? expected,
    db.ProfileOwnedData? ownedData,
  }) {
    calls++;
    return gate.future;
  }

  @override
  void cancelIfCurrent(int revision) => cancellations++;
}

void main() {
  const profile = Profile(
    id: 1,
    label: 'VPN',
    url: 'https://example.test/subscription',
    autoUpdateDuration: Duration(hours: 1),
    snapshot: ProfileSnapshot(
      revision: 1,
      generation: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  );
  late ProviderContainer container;
  late _Action action;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        vpnActionProvider.overrideWith(_Action.new),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
      ],
    );
    action = container.read(vpnActionProvider.notifier) as _Action;
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: Scaffold(body: VpnApplySettings())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Apply is single-flight and preserves profile on failure', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('vpn-apply-settings')).first);
    await tester.pump();
    await tester.tap(find.byKey(const Key('vpn-apply-settings')).first);
    expect(action.calls, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    action.gate.complete(const VpnImportResult(VpnImportOutcome.failed));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.text(currentAppLocalizations.vpnDraftSaveFailed),
      findsOneWidget,
    );
    expect(container.read(currentProfileProvider), profile);
  });

  testWidgets('leaving cancels only the active Apply request', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('vpn-apply-settings')).first);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(action.cancellations, 1);
    action.gate.complete(const VpnImportResult(VpnImportOutcome.cancelled));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual update shows progress, prevents repeats and explains timeouts',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            child: Scaffold(
              body: SingleChildScrollView(child: VpnConfigurationSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(currentAppLocalizations.update));
      await tester.pump();
      action.progress?.call(const VpnImportProgress(VpnImportStep.geodata));
      await tester.pump();
      expect(
        find.text(currentAppLocalizations.vpnImportGeodata),
        findsOneWidget,
      );
      await tester.tap(find.text(currentAppLocalizations.update));
      expect(action.calls, 1);
      action.gate.complete(
        VpnImportResult(
          VpnImportOutcome.failed,
          error: TimeoutException('private-url'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(currentAppLocalizations.vpnImportTimedOut),
        findsOneWidget,
      );
      expect(find.textContaining('private-url'), findsNothing);
      expect(container.read(currentProfileProvider), profile);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
