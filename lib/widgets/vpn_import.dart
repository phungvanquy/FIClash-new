import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showVpnImportDialog(
  BuildContext context, {
  bool replacement = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: VpnImportPanel(
            replacement: replacement,
            onImported: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    ),
  );
}

class VpnImportPanel extends ConsumerStatefulWidget {
  const VpnImportPanel({super.key, this.onImported, this.replacement = false});

  final VoidCallback? onImported;
  final bool replacement;

  @override
  ConsumerState<VpnImportPanel> createState() => _VpnImportPanelState();
}

class _VpnImportPanelState extends ConsumerState<VpnImportPanel> {
  final _url = TextEditingController();
  late VpnAction _action;
  bool _busy = false;
  bool _acquiring = false;
  String? _error;
  int? _requestRevision;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    _action = ref.read(vpnActionProvider.notifier);
  }

  Future<void> _submit(String input) async {
    if (_busy) return;
    final parsed = VpnUrlIntake.parse(input);
    if (parsed is! VpnUrlAccepted) {
      _action.cancel();
      setState(() => _error = context.appLocalizations.vpnInvalidUrl);
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = _action.importUrl(parsed.url);
      _requestRevision = _action.requestRevision;
      final result = await pending;
      if (!mounted || operation != _operation) return;
      switch (result.outcome) {
        case VpnImportOutcome.success:
          _url.clear();
          widget.onImported?.call();
        case VpnImportOutcome.failed:
          setState(() => _error = context.appLocalizations.vpnImportFailed);
        case VpnImportOutcome.recoveryRequired:
          setState(() => _error = context.appLocalizations.vpnRecoveryRequired);
        case VpnImportOutcome.cancelled:
          break;
      }
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() => _error = context.appLocalizations.vpnImportFailed);
      }
    } finally {
      if (operation == _operation) {
        _requestRevision = null;
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _paste() async {
    if (_busy || _acquiring) return;
    setState(() => _acquiring = true);
    final operation = _operation;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || _busy || operation != _operation) return;
      _url.text = data?.text ?? '';
      setState(() => _acquiring = false);
      unawaited(_submit(_url.text));
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.vpnInvalidUrl);
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _acquiring = false);
      }
    }
  }

  Future<void> _scan() async {
    if (_busy || _acquiring) return;
    setState(() => _acquiring = true);
    final operation = _operation;
    try {
      final value = system.isAndroid
          ? await Navigator.of(
              context,
            ).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()))
          : await picker.pickerConfigQRCode();
      if (!mounted || _busy || operation != _operation || value == null) return;
      _url.text = value;
      setState(() => _acquiring = false);
      unawaited(_submit(value));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is MessageException
              ? error.message
              : context.appLocalizations.pleaseUploadValidQrcode,
        );
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _acquiring = false);
      }
    }
  }

  void _cancel() {
    final revision = _requestRevision;
    if (revision != null) _action.cancelIfCurrent(revision);
    _operation++;
    _requestRevision = null;
    setState(() => _busy = false);
  }

  @override
  void dispose() {
    final revision = _requestRevision;
    if (revision != null) _action.cancelIfCurrent(revision);
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.replacement ? text.vpnReplace : text.vpnImportTitle,
            style: context.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(text.vpnImportDescription, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(
            controller: _url,
            enabled: !_busy && !_acquiring,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            inputFormatters: TextInputLimits.limit(TextInputLimits.url),
            onSubmitted: _submit,
            decoration: InputDecoration(labelText: text.vpnSubscriptionUrl),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_busy) ...[
            LinearProgressIndicator(semanticsLabel: text.vpnImporting),
            const SizedBox(height: 12),
            Text(text.vpnImporting, textAlign: TextAlign.center),
            TextButton(onPressed: _cancel, child: Text(text.cancel)),
          ] else ...[
            FilledButton(
              onPressed: _acquiring ? null : () => _submit(_url.text),
              child: Text(_error == null ? text.import : text.vpnRetry),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _acquiring ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: Text(text.vpnPasteClipboard),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _acquiring ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(system.isAndroid ? text.vpnScanQr : text.vpnQrImage),
            ),
          ],
        ],
      ),
    );
  }
}
