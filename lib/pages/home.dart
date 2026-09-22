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
          title: Text(appName, style: context.textTheme.titleLarge),
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
        final landscape =
            constraints.maxHeight < 360 && constraints.maxWidth >= 480;
        if (constraints.maxWidth >= 800 || landscape) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                children: [
                  SizedBox(
                    width: landscape
                        ? (constraints.maxWidth * .34).clamp(160, 280)
                        : 280,
                    child: control,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: servers),
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight * .36).clamp(0, 220),
              ),
              child: control,
            ),
            const Divider(height: 1),
            Expanded(child: servers),
          ],
        );
      },
    );
  }
}

class _ConnectionControl extends ConsumerStatefulWidget {
  const _ConnectionControl({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ConnectionControl> createState() => _ConnectionControlState();
}

class _ConnectionControlState extends ConsumerState<_ConnectionControl> {
  bool? _submittedIntent;
  bool _checking = false;
  int _operation = 0;

  Future<void> _retryStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(setupActionProvider.notifier).syncRunState();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _toggle(bool running) async {
    if (_submittedIntent == running) return;
    final operation = ++_operation;
    setState(() => _submittedIntent = running);
    try {
      await ref.read(setupActionProvider.notifier).setRunning(running);
    } catch (_) {
      if (mounted) {
        context.showNotifier(
          context.appLocalizations.vpnConnectionFailed,
          level: MessageLevel.error,
        );
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _submittedIntent = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final observed = ref.watch(vpnConnectionProvider);
    final ready =
        ref.watch(initProvider) &&
        profile.snapshot.generation != null &&
        ref.watch(vpnFailureProvider) != 'recovery_required';
    final text = context.appLocalizations;
    final status = switch (observed.phase) {
      VpnConnectionPhase.checking => text.vpnChecking,
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
    final action = switch (observed.phase) {
      VpnConnectionPhase.checking => text.vpnChecking,
      VpnConnectionPhase.connecting => text.connecting,
      VpnConnectionPhase.disconnecting => text.vpnDisconnecting,
      _ => active ? text.vpnDisconnect : text.vpnConnect,
    };
    final working =
        observed.phase == VpnConnectionPhase.checking ||
        observed.phase == VpnConnectionPhase.connecting ||
        observed.phase == VpnConnectionPhase.disconnecting;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final connected = observed.phase == VpnConnectionPhase.connected;
    final tone = switch (observed.phase) {
      VpnConnectionPhase.connected => Colors.green,
      VpnConnectionPhase.disconnected => Colors.grey,
      VpnConnectionPhase.connecting => Colors.orange,
      VpnConnectionPhase.disconnecting => Colors.blue,
      VpnConnectionPhase.failed => Colors.red,
      _ => Colors.blueGrey,
    };
    final color = connected
        ? const Color(0xFF00C853)
        : dark
        ? tone.shade300
        : tone.shade800;
    final foreground = connected || dark ? Colors.black : Colors.white;
    final icon = switch (observed.phase) {
      VpnConnectionPhase.checking => Icons.refresh,
      VpnConnectionPhase.connected => Icons.shield,
      VpnConnectionPhase.connecting => Icons.sync,
      VpnConnectionPhase.disconnecting => Icons.stop_circle_outlined,
      VpnConnectionPhase.failed => Icons.error_outline,
      VpnConnectionPhase.suspended => Icons.pause_circle_outline,
      VpnConnectionPhase.proxyOnly ||
      VpnConnectionPhase.localProxy => Icons.info_outline,
      VpnConnectionPhase.disconnected => Icons.shield_outlined,
    };
    final failure = switch (observed.failure) {
      null => null,
      'vpn_permission_denied' ||
      'notification_permission_denied' => text.vpnPermissionDenied,
      'system_proxy_failed' => text.vpnProxyFailure,
      'recovery_required' => text.vpnRecoveryRequired,
      'stop_failed' => text.vpnStopFailed,
      'state_unavailable' => text.vpnStateUnavailable,
      _ => text.vpnConnectionFailed,
    };
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 300;
        final button = _ConnectionButton(
          color: color,
          foreground: foreground,
          connected: connected,
          working: working || _submittedIntent != null,
          label: action,
          duration: motion,
          dimension: horizontal ? 96 : 112,
          onPressed: !working && _submittedIntent == null && (ready || active)
              ? () => _toggle(!active)
              : null,
        );
        final statusIndicator = Container(
          key: const Key('vpn-status-indicator'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: ShapeDecoration(
            color: connected ? color : Colors.transparent,
            shape: AppShape.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: connected ? foreground : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status,
                  key: const Key('vpn-status'),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: connected ? foreground : color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        final details = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: horizontal
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (profile.label.isNotEmpty)
              Tooltip(
                message: profile.label,
                excludeFromSemantics: true,
                child: Text(
                  profile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child:
                  motion == Duration.zero ||
                      observed.phase == VpnConnectionPhase.failed
                  ? statusIndicator
                  : AnimatedSize(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      alignment: horizontal
                          ? AlignmentDirectional.centerStart
                          : Alignment.center,
                      child: statusIndicator,
                    ),
            ),
            if (!working) ...[
              const SizedBox(height: 6),
              Text(action, style: context.textTheme.bodyMedium),
            ],
            if (observed.phase == VpnConnectionPhase.connecting)
              TextButton(
                key: const Key('vpn-cancel-connect'),
                onPressed: _submittedIntent == false
                    ? null
                    : () => _toggle(false),
                child: Text(text.cancel),
              ),
          ],
        );
        return SingleChildScrollView(
          key: const Key('vpn-controls-scroll'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (horizontal)
                Row(
                  children: [
                    button,
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                )
              else ...[
                button,
                const SizedBox(height: 12),
                details,
              ],
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
              if (observed.failure == 'state_unavailable')
                TextButton.icon(
                  key: const Key('vpn-retry-status'),
                  onPressed: _checking ? null : _retryStatus,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_checking ? text.vpnChecking : text.vpnRetry),
                ),
              if (profile.snapshot.routing == VpnRoutingMode.custom) ...[
                const SizedBox(height: 12),
                Text(text.vpnCustomRouting, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => showVpnImportDialog(context),
                icon: const Icon(Icons.sync_alt),
                label: Text(text.vpnReplace),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.color,
    required this.foreground,
    required this.connected,
    required this.working,
    required this.label,
    required this.duration,
    required this.dimension,
    required this.onPressed,
  });

  final Color color;
  final Color foreground;
  final bool connected;
  final bool working;
  final String label;
  final Duration duration;
  final double dimension;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: dimension,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (working)
            CircularProgressIndicator(
              strokeWidth: 2,
              value: duration == Duration.zero ? .75 : null,
              color: color,
            ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedContainer(
              key: const Key('vpn-connect-glow'),
              duration: duration,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF00C853,
                    ).withValues(alpha: connected ? (dark ? .20 : .14) : 0),
                    blurRadius: dark ? 20 : 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: FilledButton(
                  key: const Key('vpn-connect'),
                  style: FilledButton.styleFrom(
                    shape: AppShape.circle,
                    padding: EdgeInsets.zero,
                    animationDuration: duration,
                    backgroundColor: color,
                    foregroundColor: foreground,
                    disabledBackgroundColor: color,
                    disabledForegroundColor: foreground,
                  ),
                  onPressed: onPressed,
                  child: Semantics(
                    label: label,
                    child: const Icon(Icons.power_settings_new, size: 32),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveNode extends ConsumerWidget {
  const _ActiveNode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final snapshot = ref.watch(currentProfileProvider)!.snapshot;
    final current = ref.watch(vpnActiveNodeProvider);
    final server = current.asData?.value;
    final custom = snapshot.routing == VpnRoutingMode.custom;
    final label = custom
        ? text.vpnRoutingNodes
        : server?.name ??
              (current.isLoading
                  ? text.vpnNodeResolving
                  : text.vpnNodeUnavailable);
    final mode = switch (snapshot.selection) {
      VpnAutoSelection() => text.auto,
      VpnFallbackSelection() => text.fallback,
      _ => null,
    };
    final tone = Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade800;
    final detail = !custom && server != null
        ? [?mode, ?server.provider].join(' · ')
        : '';
    return Container(
      key: const Key('vpn-active-node'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: .08),
          context.colorScheme.surface,
        ),
        shape: AppShape.lg,
      ),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Tooltip(
                excludeFromSemantics: true,
                message: [
                  text.connected,
                  text.vpnCurrentNode,
                  label,
                  if (detail.isNotEmpty) detail,
                ].join('\n'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${text.connected} · ${text.vpnCurrentNode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: tone,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
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

  @override
  void didUpdateWidget(covariant VpnServerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.snapshot.generation !=
            widget.profile.snapshot.generation) {
      _operation++;
      _pending = null;
      _error = null;
    }
  }

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
    final latency = ref.watch(vpnLatencyProvider);
    final fastest = latency.fastestId;
    final connection = ref.watch(vpnConnectionProvider);
    final transitioning =
        connection.phase == VpnConnectionPhase.connecting ||
        connection.phase == VpnConnectionPhase.disconnecting;
    final canTest =
        ref.watch(initProvider) &&
        ref.watch(coreStatusProvider) == CoreStatus.connected &&
        snapshot.generation != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ServerToolbar(
          running: latency.running,
          onTest: latency.running || !canTest || transitioning
              ? null
              : () => ref.read(vpnLatencyProvider.notifier).testAll(),
        ),
        if (connection.phase == VpnConnectionPhase.connected)
          const _ActiveNode(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20;
              return ListView.builder(
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
                  final measurement = server == null
                      ? null
                      : _NodeLatency(
                          result: latency.results[server.id],
                          fastest: server.id == fastest,
                        );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Semantics(
                      selected: selected,
                      child: Tooltip(
                        message: '$title\n$subtitle',
                        excludeFromSemantics: true,
                        child: ListTile(
                          key: ValueKey(selection),
                          shape: AppShape.xl,
                          dense: true,
                          minTileHeight: 64,
                          minVerticalPadding: 8,
                          minLeadingWidth: 20,
                          horizontalTitleGap: 12,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          selected: selected,
                          selectedTileColor:
                              context.colorScheme.secondaryContainer,
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subtitle,
                                maxLines: server == null ? null : 1,
                                overflow: server == null
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (stacked && measurement != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: measurement,
                                ),
                            ],
                          ),
                          leading: Icon(
                            selected
                                ? Icons.check_circle
                                : index == 0
                                ? Icons.auto_awesome
                                : index == 1
                                ? Icons.swap_calls
                                : Icons.public,
                            size: 20,
                          ),
                          trailing: _pending == selection
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : !stacked && measurement != null
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 132,
                                  ),
                                  child: measurement,
                                )
                              : null,
                          onTap: _pending == selection || transitioning
                              ? null
                              : () => _select(selection),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServerToolbar extends StatelessWidget {
  const _ServerToolbar({required this.running, required this.onTest});

  final bool running;
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final label = running ? text.vpnLatencyTesting : text.vpnTestLatency;
    final icon = running
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: MediaQuery.disableAnimationsOf(context) ? .75 : null,
            ),
          )
        : const Icon(Icons.speed, size: 18);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 400 &&
              MediaQuery.textScalerOf(context).scale(14) > 20;
          return Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: text.vpnServers,
                  excludeFromSemantics: true,
                  child: Text(
                    text.vpnServers,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                ),
              ),
              if (compact)
                IconButton(
                  key: const Key('vpn-test-latency'),
                  tooltip: label,
                  onPressed: onTest,
                  icon: icon,
                )
              else
                Flexible(
                  child: TextButton.icon(
                    key: const Key('vpn-test-latency'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: onTest,
                    icon: icon,
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NodeLatency extends StatelessWidget {
  const _NodeLatency({required this.result, required this.fastest});

  final VpnNodeLatency? result;
  final bool fastest;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final label = switch (result?.status) {
      null => text.vpnLatencyUntested,
      VpnLatencyStatus.testing => text.vpnLatencyTesting,
      VpnLatencyStatus.measured => text.vpnLatencyMs(result!.milliseconds!),
      VpnLatencyStatus.timeout => text.vpnLatencyTimeout,
      VpnLatencyStatus.unreachable => text.vpnLatencyUnreachable,
      VpnLatencyStatus.failed => text.vpnLatencyFailed,
    };
    final measured = result?.status == VpnLatencyStatus.measured;
    final failed =
        result != null &&
        !measured &&
        result?.status != VpnLatencyStatus.testing;
    final scheme = context.colorScheme;
    final background = failed
        ? scheme.errorContainer
        : measured
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = failed
        ? scheme.onErrorContainer
        : measured
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: ShapeDecoration(color: background, shape: AppShape.sm),
          child: Text(
            label,
            style:
                (measured
                        ? context.textTheme.titleMedium
                        : context.textTheme.labelMedium)
                    ?.copyWith(color: foreground, fontWeight: FontWeight.bold),
          ),
        ),
        if (fastest)
          Text(
            text.vpnLatencyFastest,
            style: context.textTheme.labelMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.green.shade300
                  : Colors.green.shade800,
              fontWeight: FontWeight.bold,
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
