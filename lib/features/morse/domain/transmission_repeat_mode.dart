enum TransmissionRepeatMode {
  once,
  forever,
  customCount,
}

class TransmissionRepeatConfig {
  const TransmissionRepeatConfig({
    required this.mode,
    required this.customRepeatCount,
    required this.delayBetweenRepeatsMs,
  });

  final TransmissionRepeatMode mode;
  final int customRepeatCount;
  final int delayBetweenRepeatsMs;

  int? get totalRepetitions {
    switch (mode) {
      case TransmissionRepeatMode.once:
        return 1;
      case TransmissionRepeatMode.forever:
        return null;
      case TransmissionRepeatMode.customCount:
        return customRepeatCount;
    }
  }
}
