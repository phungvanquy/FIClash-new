import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/widgets/vpn_import.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _ImportAction extends VpnAction {
  final urls = <String>[];
  final pending = <Completer<VpnImportResult>>[];
  var cancelled = 0;

  @override
  Future<VpnImportResult> importUrl(String url) {
    cancel();
    urls.add(url);
    final request = Completer<VpnImportResult>();
    pending.add(request);
    return request.future;
  }

  @override
  void cancelIfCurrent(int revision) {
    if (revision == requestRevision) cancelled++;
    super.cancelIfCurrent(revision);
  }
}

void main() {
  late ProviderContainer container;
  late _ImportAction action;
  var clipboardReads = 0;
  var imported = 0;

  setUp(() {
    clipboardReads = 0;
    imported = 0;
    container = ProviderContainer(
      overrides: [vpnActionProvider.overrideWith(_ImportAction.new)],
    );
    action = container.read(vpnActionProvider.notifier) as _ImportAction;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            clipboardReads++;
            return {'text': 'https://example.test/config?token=a%2Fb'};
          }
          return null;
        });
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: VpnImportPanel(onImported: () => imported++),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows manual, paste, and QR choices without reading clipboard', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text(currentAppLocalizations.vpnPasteClipboard),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    expect(clipboardReads, 0);
  });

  testWidgets('rejects invalid input without beginning replacement', (
    tester,
  ) async {
    await pumpPanel(tester);
    final earlierRequest = action.requestRevision;
    await tester.enterText(find.byType(TextField), 'not a URL');
    await tester.tap(find.text(currentAppLocalizations.import));
    await tester.pump();
    expect(find.text(currentAppLocalizations.vpnInvalidUrl), findsOneWidget);
    expect(action.urls, isEmpty);
    expect(action.requestRevision, greaterThan(earlierRequest));
    expect(imported, 0);
  });

  testWidgets('explicit paste submits once and shows cancellable progress', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text(currentAppLocalizations.vpnPasteClipboard));
    await tester.pump();
    expect(clipboardReads, 1);
    expect(action.urls, ['https://example.test/config?token=a%2Fb']);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(currentAppLocalizations.cancel), findsOneWidget);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.success),
    );
    await tester.pumpAndSettle();
    expect(imported, 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'failure keeps entered URL and permits retry without leaking errors',
    (tester) async {
      await pumpPanel(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://example.test/config',
      );
      await tester.tap(find.text(currentAppLocalizations.import));
      await tester.pump();
      action.pending.single.complete(
        VpnImportResult(
          VpnImportOutcome.failed,
          error: StateError('secret-token-123'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(currentAppLocalizations.vpnImportFailed),
        findsOneWidget,
      );
      expect(find.textContaining('secret-token-123'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.test/config',
      );
      await tester.tap(find.text(currentAppLocalizations.vpnRetry));
      await tester.pump();
      expect(action.urls, hasLength(2));
      action.pending.last.complete(
        const VpnImportResult(VpnImportOutcome.success),
      );
      await tester.pumpAndSettle();
      expect(imported, 1);
    },
  );

  testWidgets('cancel releases controls and ignores a late result', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/config',
    );
    await tester.tap(find.text(currentAppLocalizations.import));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pumpAndSettle();
    expect(action.cancelled, 1);
    expect(find.text(currentAppLocalizations.import), findsOneWidget);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.success),
    );
    await tester.pumpAndSettle();
    expect(imported, 0);
  });

  testWidgets('disposing cancels only this panel request', (tester) async {
    await pumpPanel(tester);
    await tester.enterText(
      find.byType(TextField),
      'https://example.test/config',
    );
    await tester.tap(find.text(currentAppLocalizations.import));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(action.cancelled, 1);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.cancelled),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(imported, 0);
  });

  testWidgets('cancel after paste immediately releases retry controls', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text(currentAppLocalizations.vpnPasteClipboard));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.cancelled),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'disposing an older panel does not cancel a newer external import',
    (tester) async {
      await pumpPanel(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://example.test/old',
      );
      await tester.tap(find.text(currentAppLocalizations.import));
      await tester.pump();
      unawaited(action.importUrl('https://example.test/new'));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(action.cancelled, 0);
      for (final pending in action.pending) {
        pending.complete(const VpnImportResult(VpnImportOutcome.cancelled));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
