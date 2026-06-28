class TimingInstruction {
  const TimingInstruction({
    required this.isOn,
    required this.durationMs,
    required this.symbol,
    required this.phaseLabel,
  });

  final bool isOn;
  final int durationMs;
  final String symbol;
  final String phaseLabel;
}
