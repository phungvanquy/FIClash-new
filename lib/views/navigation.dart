import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:material_ui/material_ui.dart';

class Navigation implements NavigationPort {
  static final Navigation _instance = Navigation._internal();

  Navigation._internal();

  factory Navigation() => _instance;

  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) => [
    NavigationItem(
      icon: const Icon(Icons.home_outlined),
      label: PageLabel.dashboard,
      builder: (_) => const HomePage(),
    ),
    NavigationItem(
      icon: const Icon(Icons.settings_outlined),
      label: PageLabel.tools,
      builder: (_) => const ToolsView(),
    ),
  ];
}

final navigation = Navigation();
