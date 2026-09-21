import 'package:fl_clash/common/proxy.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _pendingUpdate = Future.value();
  int _revision = 0;

  Future<void> _updateProxy(ProxyState proxyState, int revision) async {
    if (!mounted || revision != _revision) return;
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    final installing = isStart && systemProxy;
    final adapter = ref.read(systemProxyAdapterProvider);
    final notifier = ref.read(systemProxyStateProvider.notifier);
    notifier.value = notifier.value.copyWith(pending: true, failure: null);
    var succeeded = false;
    try {
      succeeded =
          (installing
              ? await adapter?.startProxy(port, proxyState.bassDomain)
              : await adapter?.stopProxy()) ==
          true;
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) {
      if (installing) {
        try {
          await adapter?.stopProxy();
        } catch (_) {
          commonPrint.log(
            'system proxy cleanup failed',
            logLevel: LogLevel.warning,
          );
        }
      }
      return;
    }
    final previous = notifier.value;
    notifier.value = SystemProxyObservation(
      pending: revision != _revision,
      installed: succeeded ? installing : previous.installed,
      port: succeeded ? (installing ? port : 0) : previous.port,
      failure: !succeeded && (installing || previous.installed)
          ? 'system_proxy_failed'
          : null,
    );
    if (!succeeded) {
      commonPrint.log('update system proxy failed', logLevel: LogLevel.warning);
    }
  }

  void _scheduleUpdateProxy(ProxyState proxyState) {
    final revision = ++_revision;
    _pendingUpdate = _pendingUpdate
        .then((_) => _updateProxy(proxyState, revision))
        .catchError((Object error) {
          commonPrint.log(
            'update system proxy failed: $error',
            logLevel: LogLevel.warning,
          );
        });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _scheduleUpdateProxy(next);
      }
    }, fireImmediately: true);
    ref.listenManual(vpnPendingProvider, (prev, next) {
      if (prev == false && next == null) {
        _scheduleUpdateProxy(ref.read(proxyStateProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
