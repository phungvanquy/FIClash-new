import 'package:fl_clash/common/common.dart';
import 'package:material_ui/material_ui.dart';

class VpnImportProgressView extends StatelessWidget {
  const VpnImportProgressView({
    super.key,
    this.progress,
    this.cancelling = false,
  });

  final VpnImportProgress? progress;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final current = progress;
    final label = cancelling
        ? text.vpnImportCancelling
        : switch (current?.step) {
            VpnImportStep.download => text.vpnImportDownloading,
            VpnImportStep.providers => text.vpnImportProviders(
              current!.completed,
              current.total,
            ),
            VpnImportStep.geodata => text.vpnImportGeodata,
            VpnImportStep.validation => text.vpnImportValidating,
            VpnImportStep.saving => text.vpnImportSaving,
            VpnImportStep.activating => text.vpnImportActivating,
            VpnImportStep.finalizing => text.vpnImportFinalizing,
            null => text.vpnImporting,
          };
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(semanticsLabel: label),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
