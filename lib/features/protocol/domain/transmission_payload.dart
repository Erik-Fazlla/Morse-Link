enum TransmissionPayloadType {
  freeText,
  emergencyCommand,
}

enum EmergencyCommand {
  sos,
  help,
  safe,
  needWater,
  needMedical,
}

class TransmissionPayload {
  const TransmissionPayload({
    required this.type,
    required this.userMessage,
    required this.normalizedText,
    required this.packetLabel,
    this.command,
  });

  final TransmissionPayloadType type;
  final String userMessage;
  final String normalizedText;
  final String packetLabel;
  final EmergencyCommand? command;

  bool get isEmpty => normalizedText.isEmpty;
}
