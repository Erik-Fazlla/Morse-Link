class TransmissionHistoryEntry {
  const TransmissionHistoryEntry({
    required this.messageText,
    required this.timestampIso,
    required this.durationMs,
    required this.timingUnitMs,
    required this.repeatMode,
    required this.repeatCount,
    required this.delayBetweenRepeatsMs,
  });

  final String messageText;
  final String timestampIso;
  final int durationMs;
  final int timingUnitMs;
  final String repeatMode;
  final int repeatCount;
  final int delayBetweenRepeatsMs;

  DateTime get timestamp => DateTime.parse(timestampIso);

  Map<String, Object> toJson() {
    return {
      'messageText': messageText,
      'timestampIso': timestampIso,
      'durationMs': durationMs,
      'timingUnitMs': timingUnitMs,
      'repeatMode': repeatMode,
      'repeatCount': repeatCount,
      'delayBetweenRepeatsMs': delayBetweenRepeatsMs,
    };
  }

  factory TransmissionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TransmissionHistoryEntry(
      messageText: json['messageText'] as String? ?? '',
      timestampIso: json['timestampIso'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      durationMs: json['durationMs'] as int? ?? 0,
      timingUnitMs: json['timingUnitMs'] as int? ?? 180,
      repeatMode: json['repeatMode'] as String? ?? 'once',
      repeatCount: json['repeatCount'] as int? ?? 1,
      delayBetweenRepeatsMs: json['delayBetweenRepeatsMs'] as int? ?? 400,
    );
  }
}
