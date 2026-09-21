import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tray/tray.dart';

import 'app_localizations.dart';
import 'dialog.dart';
import 'app_ports.dart';
import 'constant.dart';
import 'provider_reader.dart';
import 'system.dart';
import 'window.dart';

class AppTray implements TrayPort {
  static AppTray? _instance;

  final bool isMacOS;
  final bool isWindows;

  bool _isShutDown = false;

  AppTray._internal({required this.isMacOS, required this.isWindows});

  factory AppTray() {
    _instance ??= AppTray._internal(
      isMacOS: system.isMacOS,
      isWindows: system.isWindows,
    );
    return _instance!;
  }

  @visibleForTesting
  factory AppTray.forPlatform({
    required bool isMacOS,
    required bool isWindows,
  }) {
    return AppTray._internal(isMacOS: isMacOS, isWindows: isWindows);
  }

  String get _trayIconSuffix {
    return isWindows ? 'ico' : 'png';
  }

  String get _trayIconDir {
    return isWindows ? 'assets/images/tray/windows' : 'assets/images/tray/unix';
  }

  String getTrayIcon({required bool isStart, required bool tunEnable}) {
    final status = switch ((isMacOS || !isStart, tunEnable)) {
      (true, _) => 1,
      (false, false) => 2,
      (false, true) => 3,
    };
    return '$_trayIconDir/status_$status.$_trayIconSuffix';
  }

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) {
      return;
    }
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(
          getTrayIcon(
            isStart: trayState.isStart,
            tunEnable: trayState.tunEnable,
          ),
          isTemplate: isMacOS,
        ),
        toolTip: appName,
        menu: buildMenu(trayState: trayState, read: read),
      ),
    );
    await updateTitle(showTrayTitle: trayState.showTrayTitle, traffic: traffic);
  }

  Future<void> updateTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  }) async {
    if (_isShutDown || !isMacOS) {
      return;
    }
    await Tray.instance.setTitle(showTrayTitle ? traffic.trayTitle : '');
  }

  @visibleForTesting
  List<TrayMenuItem> buildMenu({
    required TrayState trayState,
    required ProviderReader read,
  }) {
    final text = currentAppLocalizations;
    final profile = trayState.profile;
    final canDisconnect = trayState.connection.canDisconnect;
    void open(PageLabel page) {
      read(currentPageLabelProvider.notifier).toPage(page);
      window?.show();
    }

    TrayMenuCheckbox node(String label, VpnSelection selection) =>
        TrayMenuCheckbox(
          label: label,
          checked:
              profile?.snapshot.routing == VpnRoutingMode.simple &&
              profile?.snapshot.selection == selection,
          onSelected: () async {
            try {
              final selected = await read(
                proxiesActionProvider.notifier,
              ).selectVpn(selection);
              if (!selected) {
                dialogs.showNotifier(
                  text.vpnSelectFailed,
                  level: MessageLevel.error,
                );
              }
            } catch (_) {
              dialogs.showNotifier(
                text.vpnSelectFailed,
                level: MessageLevel.error,
              );
            }
          },
        );
    return [
      TrayMenuAction(
        label: text.vpnHome,
        onSelected: () => open(PageLabel.dashboard),
      ),
      TrayMenuAction(
        label: canDisconnect ? text.vpnDisconnect : text.vpnConnect,
        enabled: canDisconnect || profile?.snapshot.generation != null,
        onSelected: read(commonActionProvider.notifier).toggleRunning,
      ),
      if (profile != null)
        TrayMenuSubmenu(
          label: text.vpnServers,
          items: [
            node(text.auto, const VpnSelection.auto()),
            node(text.fallback, const VpnSelection.fallback()),
            for (final server in profile.snapshot.servers)
              node(server.name, VpnSelection.server(server.id)),
          ],
        ),
      TrayMenuAction(
        label: text.settings,
        onSelected: () => open(PageLabel.tools),
      ),
      const TrayMenuSeparator(),
      TrayMenuAction(
        label: text.exit,
        onSelected: read(systemActionProvider.notifier).handleExit,
      ),
    ];
  }
}

final appTray = system.isDesktop ? AppTray() : null;
