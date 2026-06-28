import '../domain/transmission_payload.dart';

class CommunicationProtocolService {
  static const Map<EmergencyCommand, String> _commandTexts = {
    EmergencyCommand.sos: 'SOS',
    EmergencyCommand.help: 'HELP',
    EmergencyCommand.safe: 'SAFE',
    EmergencyCommand.needWater: 'NEED WATER',
    EmergencyCommand.needMedical: 'NEED MEDICAL',
  };

  static const Map<String, EmergencyCommand> _recognizedCommands = {
    'SOS': EmergencyCommand.sos,
    'HELP': EmergencyCommand.help,
    'SAFE': EmergencyCommand.safe,
    'NEED WATER': EmergencyCommand.needWater,
    'NEED MEDICAL': EmergencyCommand.needMedical,
  };

  TransmissionPayload buildPayloadFromUserMessage(String message) {
    final normalized = _normalizeText(message);
    final command = _recognizedCommands[normalized];

    if (command != null) {
      return buildEmergencyCommandPayload(command);
    }

    return TransmissionPayload(
      type: TransmissionPayloadType.freeText,
      userMessage: message,
      normalizedText: normalized,
      packetLabel: normalized.isEmpty ? 'EMPTY' : 'TEXT',
    );
  }

  TransmissionPayload buildEmergencyCommandPayload(EmergencyCommand command) {
    final normalized = _commandTexts[command]!;

    return TransmissionPayload(
      type: TransmissionPayloadType.emergencyCommand,
      userMessage: normalized,
      normalizedText: normalized,
      packetLabel: _packetLabelFor(command),
      command: command,
    );
  }

  TransmissionPayload parseNormalizedPayload(String normalizedText) {
    final normalized = _normalizeText(normalizedText);
    final command = _recognizedCommands[normalized];

    if (command != null) {
      return buildEmergencyCommandPayload(command);
    }

    return TransmissionPayload(
      type: TransmissionPayloadType.freeText,
      userMessage: normalizedText,
      normalizedText: normalized,
      packetLabel: normalized.isEmpty ? 'EMPTY' : 'TEXT',
    );
  }

  List<TransmissionPayload> get predefinedEmergencyPayloads {
    return EmergencyCommand.values
        .map(buildEmergencyCommandPayload)
        .toList(growable: false);
  }

  String _normalizeText(String text) {
    return text.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _packetLabelFor(EmergencyCommand command) {
    switch (command) {
      case EmergencyCommand.sos:
        return 'CMD:SOS';
      case EmergencyCommand.help:
        return 'CMD:HELP';
      case EmergencyCommand.safe:
        return 'CMD:SAFE';
      case EmergencyCommand.needWater:
        return 'CMD:NEED_WATER';
      case EmergencyCommand.needMedical:
        return 'CMD:NEED_MEDICAL';
    }
  }
}
