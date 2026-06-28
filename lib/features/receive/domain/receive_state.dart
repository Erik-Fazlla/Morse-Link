import 'signal_quality.dart';
import 'sync_phase.dart';

enum ReceiveStatus { idle, starting, receiving, stopped, error }

/// Immutable snapshot of the receive session for the UI.
class ReceiveState {
  const ReceiveState({
    required this.status,
    required this.syncPhase,
    required this.quality,
    required this.liveMorse,
    required this.decodedText,
    this.errorMessage,
  });

  final ReceiveStatus status;
  final SyncPhase syncPhase;
  final SignalQuality quality;
  final String liveMorse;
  final String decodedText;
  final String? errorMessage;

  static const idle = ReceiveState(
    status: ReceiveStatus.idle,
    syncPhase: SyncPhase.searching,
    quality: SignalQuality.idle,
    liveMorse: '',
    decodedText: '',
  );

  bool get isReceiving => status == ReceiveStatus.receiving;
  bool get hasError => status == ReceiveStatus.error;

  ReceiveState copyWith({
    ReceiveStatus? status,
    SyncPhase? syncPhase,
    SignalQuality? quality,
    String? liveMorse,
    String? decodedText,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ReceiveState(
        status: status ?? this.status,
        syncPhase: syncPhase ?? this.syncPhase,
        quality: quality ?? this.quality,
        liveMorse: liveMorse ?? this.liveMorse,
        decodedText: decodedText ?? this.decodedText,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
