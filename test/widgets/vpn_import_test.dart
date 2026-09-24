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
  VpnProgressCallback? progress;

  @override
  Future<VpnImportResult> importUrl(
    String url, {
    VpnProgressCallback? onProgress,
  }) {
    progress = onProgress;
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
        find.textContaining(currentAppLocalizations.vpnImportFailed),
        findsOneWidget,
      );
      expect(find.textContaining('secret-token-123'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data!.contains('phase=unknown, error=StateError'),
        ),
        findsOneWidget,
      );
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

  testWidgets('cancel waits for cleanup before releasing controls', (
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
    await tester.pump();
    expect(action.cancelled, 1);
    expect(
      find.text(currentAppLocalizations.vpnImportCancelling),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    action.progress?.call(const VpnImportProgress(VpnImportStep.validation));
    await tester.pump();
    expect(
      find.text(currentAppLocalizations.vpnImportCancelling),
      findsOneWidget,
    );
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.cancelled),
    );
    await tester.pumpAndSettle();
    expect(imported, 0);
    expect(find.text(currentAppLocalizations.import), findsOneWidget);
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

  testWidgets('timeout offers a safe retry without exposing download details', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text(currentAppLocalizations.vpnPasteClipboard));
    await tester.pump();
    action.pending.single.complete(
      VpnImportResult(
        VpnImportOutcome.failed,
        error: TimeoutException('private-token'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(currentAppLocalizations.vpnImportTimedOut),
      findsOneWidget,
    );
    expect(find.textContaining('private-token'), findsNothing);
    expect(find.text(currentAppLocalizations.vpnRetry), findsOneWidget);
  });

  testWidgets('cancel after paste releases retry controls after cleanup', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text(currentAppLocalizations.vpnPasteClipboard));
    await tester.pump();
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.cancelled),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows stage counts and protects activation from cancellation', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.tap(find.text(currentAppLocalizations.vpnPasteClipboard));
    await tester.pump();
    action.progress?.call(
      const VpnImportProgress(VpnImportStep.providers, completed: 2, total: 4),
    );
    await tester.pump();
    expect(
      find.text(currentAppLocalizations.vpnImportProviders(2, 4)),
      findsOneWidget,
    );
    action.progress?.call(const VpnImportProgress(VpnImportStep.activating));
    await tester.pump();
    expect(
      find.text(currentAppLocalizations.vpnImportActivating),
      findsOneWidget,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    action.pending.single.complete(
      const VpnImportResult(VpnImportOutcome.success),
    );
    await tester.pumpAndSettle();
    expect(imported, 1);
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
