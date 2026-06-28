/// Two distinct measures, never merged:
/// - [signalStrengthPct]: optical contrast (ON vs OFF luminance).
/// - [decodeConfidencePct]: timing fit of pulses to unit multiples.
class SignalQuality {
  const SignalQuality({
    this.detected = false,
    this.estUnitMs = 0,
    this.signalStrengthPct = 0,
    this.decodeConfidencePct = 0,
  });

  final bool detected;
  final int estUnitMs;
  final double signalStrengthPct;
  final double decodeConfidencePct;

  static const idle = SignalQuality();

  SignalQuality copyWith({
    bool? detected,
    int? estUnitMs,
    double? signalStrengthPct,
    double? decodeConfidencePct,
  }) =>
      SignalQuality(
        detected: detected ?? this.detected,
        estUnitMs: estUnitMs ?? this.estUnitMs,
        signalStrengthPct: signalStrengthPct ?? this.signalStrengthPct,
        decodeConfidencePct: decodeConfidencePct ?? this.decodeConfidencePct,
      );
}
