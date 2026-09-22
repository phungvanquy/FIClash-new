enum VpnImportStep {
  download,
  providers,
  geodata,
  validation,
  saving,
  activating,
  finalizing,
}

class VpnImportProgress {
  const VpnImportProgress(this.step, {this.completed = 0, this.total = 0});

  final VpnImportStep step;
  final int completed;
  final int total;

  bool get canCancel => switch (step) {
    VpnImportStep.activating || VpnImportStep.finalizing => false,
    _ => true,
  };
}

typedef VpnProgressCallback = void Function(VpnImportProgress progress);
