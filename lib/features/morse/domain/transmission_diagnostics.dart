import 'transmission_state.dart';

class TransmissionDiagnostics {
  const TransmissionDiagnostics({
    required this.status,
    required this.currentSymbol,
    required this.currentPhase,
    required this.currentDurationMs,
    required this.timingUnitMs,
    required this.currentRepeat,
    required this.totalRepeats,
    required this.elapsedMs,
  });

  final TransmissionStatus status;
  final String currentSymbol;
  final String currentPhase;
  final int currentDurationMs;
  final int timingUnitMs;
  final int currentRepeat;
  final int? totalRepeats;
  final int elapsedMs;

  int get currentDuration => currentDurationMs;
  int get timingUnit => timingUnitMs;
  int get repeatCount => currentRepeat;
  int get elapsedTime => elapsedMs;

  static const idle = TransmissionDiagnostics(
    status: TransmissionStatus.idle,
    currentSymbol: '-',
    currentPhase: 'idle',
    currentDurationMs: 0,
    timingUnitMs: 0,
    currentRepeat: 0,
    totalRepeats: null,
    elapsedMs: 0,
  );

  TransmissionDiagnostics copyWith({
    TransmissionStatus? status,
    String? currentSymbol,
    String? currentPhase,
    int? currentDurationMs,
    int? timingUnitMs,
    int? currentRepeat,
    int? totalRepeats,
    int? elapsedMs,
  }) {
    return TransmissionDiagnostics(
      status: status ?? this.status,
      currentSymbol: currentSymbol ?? this.currentSymbol,
      currentPhase: currentPhase ?? this.currentPhase,
      currentDurationMs: currentDurationMs ?? this.currentDurationMs,
      timingUnitMs: timingUnitMs ?? this.timingUnitMs,
      currentRepeat: currentRepeat ?? this.currentRepeat,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      elapsedMs: elapsedMs ?? this.elapsedMs,
    );
  }
}
