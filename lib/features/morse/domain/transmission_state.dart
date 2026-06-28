enum TransmissionStatus {
  idle,
  transmitting,
  paused,
  stopped,
  error,
}

class TransmissionState {
  const TransmissionState({
    required this.status,
    required this.isLightOn,
    required this.currentRepeat,
    required this.totalRepeats,
    required this.isWaitingBetweenRepeats,
    this.errorMessage,
  });

  final TransmissionStatus status;
  final bool isLightOn;
  final int currentRepeat;
  final int? totalRepeats;
  final bool isWaitingBetweenRepeats;
  final String? errorMessage;

  static const idle = TransmissionState(
    status: TransmissionStatus.idle,
    isLightOn: false,
    currentRepeat: 0,
    totalRepeats: null,
    isWaitingBetweenRepeats: false,
  );

  static const paused = TransmissionState(
    status: TransmissionStatus.paused,
    isLightOn: false,
    currentRepeat: 0,
    totalRepeats: null,
    isWaitingBetweenRepeats: false,
  );

  static const stopped = TransmissionState(
    status: TransmissionStatus.stopped,
    isLightOn: false,
    currentRepeat: 0,
    totalRepeats: null,
    isWaitingBetweenRepeats: false,
  );

  factory TransmissionState.transmitting({
    required bool isLightOn,
    required int currentRepeat,
    required int? totalRepeats,
    bool isWaitingBetweenRepeats = false,
  }) {
    return TransmissionState(
      status: TransmissionStatus.transmitting,
      isLightOn: isLightOn,
      currentRepeat: currentRepeat,
      totalRepeats: totalRepeats,
      isWaitingBetweenRepeats: isWaitingBetweenRepeats,
    );
  }

  factory TransmissionState.error(String message) {
    return TransmissionState(
      status: TransmissionStatus.error,
      isLightOn: false,
      currentRepeat: 0,
      totalRepeats: null,
      isWaitingBetweenRepeats: false,
      errorMessage: message,
    );
  }

  bool get isActive =>
      status == TransmissionStatus.transmitting ||
      status == TransmissionStatus.paused;

  int get repeatCount => currentRepeat;

  bool get canStart =>
      status == TransmissionStatus.idle ||
      status == TransmissionStatus.stopped ||
      status == TransmissionStatus.error;

  bool get canStop => isActive;

  TransmissionState copyWith({
    TransmissionStatus? status,
    bool? isLightOn,
    int? currentRepeat,
    int? totalRepeats,
    bool? isWaitingBetweenRepeats,
    String? errorMessage,
  }) {
    return TransmissionState(
      status: status ?? this.status,
      isLightOn: isLightOn ?? this.isLightOn,
      currentRepeat: currentRepeat ?? this.currentRepeat,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      isWaitingBetweenRepeats:
          isWaitingBetweenRepeats ?? this.isWaitingBetweenRepeats,
      errorMessage: errorMessage,
    );
  }
}
