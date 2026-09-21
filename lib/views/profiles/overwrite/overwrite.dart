import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/profiles/preview.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom/custom.dart';
import 'script.dart';
import 'standard.dart';

class OverwriteView extends ConsumerStatefulWidget {
  final int profileId;

  const OverwriteView({super.key, required this.profileId});

  @override
  ConsumerState<OverwriteView> createState() => _OverwriteViewState();
}

class _OverwriteViewState extends ConsumerState<OverwriteView> {
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.listenManual(profileDraftProvider(widget.profileId), (_, _) {});
    ref.listenManual(clashConfigProvider(widget.profileId), (_, _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(profileDraftProvider(widget.profileId).notifier).open();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.appLocalizations.vpnSettingsActionFailed,
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      final result = await ref
          .read(profileDraftProvider(widget.profileId).notifier)
          .save();
      if (!mounted) return;
      if (result.outcome != VpnImportOutcome.success) {
        setState(
          () => _error = result.outcome == VpnImportOutcome.recoveryRequired
              ? context.appLocalizations.vpnRecoveryRequired
              : context.appLocalizations.vpnDraftSaveFailed,
        );
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.vpnDraftSaveFailed);
      }
    }
  }

  Future<void> _handlePreview() async {
    final draft = ref.read(profileDraftProvider(widget.profileId));
    if (draft == null) {
      return;
    }
    unawaited(
      BaseNavigator.push<String>(
        context,
        PreviewProfileView(
          profile: draft.profile,
          loadContent: () =>
              ref.read(vpnActionProvider.notifier).previewDraft(draft),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final draft = ref.watch(profileDraftProvider(widget.profileId));
    final enabled = draft != null && !draft.saving;
    return ProfileIdProvider(
      profileId: widget.profileId,
      child: CommonScaffold(
        title: appLocalizations.override,
        actions: [
          CommonMinFilledButtonTheme(
            child: FilledButton(
              onPressed: enabled ? _handlePreview : null,
              child: Text(appLocalizations.preview),
            ),
          ),
          CommonMinFilledButtonTheme(
            child: FilledButton(
              key: const Key('vpn-save-overrides'),
              onPressed: enabled ? _save : null,
              child: Text(appLocalizations.save),
            ),
          ),
          const SizedBox(width: 8),
        ],
        body: Column(
          children: [
            if (draft == null && _error == null || draft?.saving == true)
              const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(appLocalizations.vpnDraftDescription),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              ),
            if (draft == null && _error != null)
              TextButton(
                onPressed: _open,
                child: Text(appLocalizations.vpnRetry),
              ),
            if (draft != null)
              Expanded(
                child: AbsorbPointer(
                  absorbing: !enabled,
                  child: const ScrollConfiguration(
                    behavior: ShowBarScrollBehavior(),
                    child: CustomScrollView(slivers: [_Title(), _Content()]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends ConsumerWidget {
  const _Title();

  String _getTitle(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standard,
      OverwriteType.script => context.appLocalizations.script,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustom,
    };
  }

  IconData _getIcon(OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => Icons.stars,
      OverwriteType.script => Icons.rocket,
      OverwriteType.custom => Icons.dashboard_customize,
    };
  }

  String _getDesc(BuildContext context, OverwriteType type) {
    return switch (type) {
      OverwriteType.standard => context.appLocalizations.standardModeDesc,
      OverwriteType.script => context.appLocalizations.scriptModeDesc,
      OverwriteType.custom => context.appLocalizations.overwriteTypeCustomDesc,
    };
  }

  void _handleChangeType(WidgetRef ref, int profileId, OverwriteType type) {
    ref.read(profileDraftProvider(profileId).notifier).updateProfile((state) {
      return state.copyWith(overwriteType: type);
    });
  }

  @override
  Widget build(context, ref) {
    final appLocalizations = context.appLocalizations;
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoHeader(info: Info(label: appLocalizations.overrideMode)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 16,
              children: [
                for (final type in OverwriteType.values)
                  CommonCard(
                    isSelected: overwriteType == type,
                    onPressed: () {
                      _handleChangeType(ref, profileId, type);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(_getIcon(type)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(_getTitle(context, type))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _getDesc(context, overwriteType),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant.opacity80,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, ref) {
    final profileId = ProfileIdProvider.of(context)!.profileId;
    final overwriteType = ref.watch(overwriteTypeProvider(profileId));
    return switch (overwriteType) {
      OverwriteType.standard => const StandardContent(),
      OverwriteType.script => const ScriptContent(),
      OverwriteType.custom => const CustomContent(),
    };
  }
}
