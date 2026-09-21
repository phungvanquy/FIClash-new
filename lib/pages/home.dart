import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:fl_clash/widgets/vpn_import.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentPageLabelProvider, (_, next) {
      if (next == PageLabel.tools && !_settingsOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openSettings();
        });
      }
      if (next == PageLabel.dashboard && _settingsOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _settingsOpen) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    });
  }

  Future<void> _openSettings() async {
    if (_settingsOpen) return;
    _settingsOpen = true;
    ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools);
    try {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const ToolsView()));
    } finally {
      _settingsOpen = false;
      if (mounted) {
        ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.dashboard);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return HomeBackScopeContainer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text(appName),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              key: const Key('vpn-settings'),
              tooltip: context.appLocalizations.settings,
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: profile == null
              ? const _ImportHome()
              : _ConfiguredHome(profile: profile),
        ),
      ),
    );
  }
}

class _ImportHome extends StatelessWidget {
  const _ImportHome();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const VpnImportPanel(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfiguredHome extends StatelessWidget {
  const _ConfiguredHome({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final control = _ConnectionControl(profile: profile);
        final servers = VpnServerList(profile: profile);
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              Expanded(child: control),
              const VerticalDivider(width: 1),
              Expanded(child: servers),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: control),
            const Divider(height: 1),
            Expanded(child: servers),
          ],
        );
      },
    );
  }
}

class _ConnectionControl extends ConsumerWidget {
  const _ConnectionControl({required this.profile});

  final Profile profile;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool running,
  ) async {
    try {
      await ref.read(setupActionProvider.notifier).setRunning(running);
    } catch (_) {
      if (context.mounted) {
        context.showNotifier(
          context.appLocalizations.vpnConnectionFailed,
          level: MessageLevel.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observed = ref.watch(vpnConnectionProvider);
    final ready =
        ref.watch(initProvider) &&
        profile.snapshot.generation != null &&
        ref.watch(vpnFailureProvider) != 'recovery_required';
    final text = context.appLocalizations;
    final status = switch (observed.phase) {
      VpnConnectionPhase.disconnected => text.disconnected,
      VpnConnectionPhase.connecting => text.connecting,
      VpnConnectionPhase.connected => text.connected,
      VpnConnectionPhase.disconnecting => text.vpnDisconnecting,
      VpnConnectionPhase.proxyOnly => text.vpnProxyOnly,
      VpnConnectionPhase.localProxy => text.vpnLocalProxy,
      VpnConnectionPhase.suspended => text.vpnSuspended,
      VpnConnectionPhase.failed => text.vpnConnectionFailed,
    };
    final active = observed.canDisconnect;
    final action = active ? text.vpnDisconnect : text.vpnConnect;
    final working =
        observed.phase == VpnConnectionPhase.connecting ||
        observed.phase == VpnConnectionPhase.disconnecting;
    final failure = switch (observed.failure) {
      null => null,
      'vpn_permission_denied' ||
      'notification_permission_denied' => text.vpnPermissionDenied,
      'system_proxy_failed' => text.vpnProxyFailure,
      'recovery_required' => text.vpnRecoveryRequired,
      _ => text.vpnConnectionFailed,
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('vpn-controls-scroll'),
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile.label.isNotEmpty) ...[
                Text(
                  profile.label,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
              ],
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const Key('vpn-status'),
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox.square(
                dimension: constraints.maxHeight < 400 ? 136 : 184,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (working) const CircularProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Tooltip(
                        message: action,
                        child: FilledButton(
                          key: const Key('vpn-connect'),
                          style: FilledButton.styleFrom(shape: AppShape.circle),
                          onPressed: ready || active
                              ? () => _toggle(context, ref, !active)
                              : null,
                          child: Semantics(
                            label: action,
                            child: const Icon(
                              Icons.power_settings_new,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(action, textAlign: TextAlign.center),
              if (failure != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failure,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              ],
              if (profile.snapshot.routing == VpnRoutingMode.custom) ...[
                const SizedBox(height: 12),
                Text(text.vpnCustomRouting, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => showVpnImportDialog(context),
                icon: const Icon(Icons.sync_alt),
                label: Text(text.vpnReplace),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VpnServerList extends ConsumerStatefulWidget {
  const VpnServerList({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<VpnServerList> createState() => _VpnServerListState();
}

class _VpnServerListState extends ConsumerState<VpnServerList> {
  VpnSelection? _pending;
  int _operation = 0;
  String? _error;

  Future<void> _select(VpnSelection selection) async {
    final operation = ++_operation;
    setState(() {
      _pending = selection;
      _error = null;
    });
    try {
      final selected = await ref
          .read(proxiesActionProvider.notifier)
          .selectVpn(selection);
      if (!selected && mounted && operation == _operation) {
        setState(() => _error = context.appLocalizations.vpnSelectFailed);
      }
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() => _error = context.appLocalizations.vpnSelectFailed);
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final snapshot = widget.profile.snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(text.vpnServers, style: context.textTheme.titleMedium),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('vpn-servers'),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: snapshot.servers.length + 2,
            itemBuilder: (context, index) {
              final server = index < 2 ? null : snapshot.servers[index - 2];
              final selection = switch (index) {
                0 => const VpnSelection.auto(),
                1 => const VpnSelection.fallback(),
                _ => VpnSelection.server(server!.id),
              };
              final title = index == 0
                  ? text.auto
                  : index == 1
                  ? text.fallback
                  : server!.name;
              final subtitle = index == 0
                  ? text.vpnAutoDescription
                  : index == 1
                  ? text.vpnFallbackDescription
                  : [server!.type, ?server.provider].join(' · ');
              final selected =
                  snapshot.routing == VpnRoutingMode.simple &&
                  snapshot.selection == selection;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Semantics(
                  selected: selected,
                  child: ListTile(
                    key: ValueKey(selection),
                    shape: AppShape.xl,
                    selected: selected,
                    selectedTileColor: context.colorScheme.secondaryContainer,
                    title: Text(title),
                    subtitle: Text(subtitle),
                    leading: Icon(
                      index == 0
                          ? Icons.auto_awesome
                          : index == 1
                          ? Icons.swap_calls
                          : Icons.public,
                    ),
                    trailing: _pending == selection
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                          ),
                    onTap: _pending == selection
                        ? null
                        : () => _select(selection),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class HomeBackScopeContainer extends ConsumerWidget {
  const HomeBackScopeContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonPopScope(
      onPop: (_) async {
        await ref.read(systemActionProvider.notifier).handleClose();
        return false;
      },
      child: child,
    );
  }
}
