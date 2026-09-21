import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PreviewProfileView extends ConsumerStatefulWidget {
  final Profile profile;
  final Future<String> Function()? loadContent;

  const PreviewProfileView({
    super.key,
    required this.profile,
    this.loadContent,
  });

  @override
  ConsumerState<PreviewProfileView> createState() => _PreviewProfileViewState();
}

class _PreviewProfileViewState extends ConsumerState<PreviewProfileView> {
  final contentNotifier = ValueNotifier<String?>(null);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final content =
            await (widget.loadContent?.call() ??
                ref
                    .read(setupActionProvider.notifier)
                    .getProfileWithId(widget.profile.id));
        if (mounted) contentNotifier.value = content;
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
    });
  }

  @override
  void dispose() {
    contentNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.profile.realLabel)),
        body: Center(
          child: Text(context.appLocalizations.vpnSettingsActionFailed),
        ),
      );
    }
    return ValueListenableBuilder(
      valueListenable: contentNotifier,
      builder: (_, content, _) {
        final title = widget.profile.realLabel;

        return EditorPage(
          key: const Key('content'),
          title: title,
          content: content,
        );
      },
    );
  }
}
