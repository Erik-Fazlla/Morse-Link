import 'package:flutter/material.dart';

import '../../../history/services/transmission_history_repository.dart';
import '../../../library/services/saved_message_repository.dart';
import '../../../morse/domain/transmission_repeat_mode.dart';
import '../../../morse/services/morse_translator.dart';
import '../../../morse/services/morse_transmission_service.dart';
import '../../../morse/services/timing_sequence_builder.dart';
import '../../../morse/services/torch_flashlight_controller.dart';
import '../../../protocol/services/communication_protocol_service.dart';
import '../send_controller.dart';
import 'send_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final TransmissionHistoryRepository _historyRepository =
      TransmissionHistoryRepository();
  static final SavedMessageRepository _savedMessageRepository =
      SavedMessageRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'MORSE',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.8,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Offline optical emergency communication.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF9D9D9D),
                    ),
              ),
              const SizedBox(height: 20),
              const Spacer(),
              _ActionPanel(
                title: 'SEND',
                subtitle: 'Type a message and transmit it with the flashlight.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SendSessionScreen(
                        controller: _buildSendController(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const _DisabledPanel(
                title: 'RECEIVE',
                subtitle: 'Coming Soon',
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  SendController _buildSendController({
    String initialMessage = 'SOS',
    int initialTimingUnitMs = 180,
    TransmissionRepeatMode initialRepeatMode = TransmissionRepeatMode.once,
    int initialCustomRepeatCount = 3,
    int initialDelayBetweenRepeatsMs = 400,
  }) {
    return SendController(
      historyRepository: _historyRepository,
      savedMessageRepository: _savedMessageRepository,
      protocolService: CommunicationProtocolService(),
      translator: MorseTranslator(),
      timingBuilder: TimingSequenceBuilder(),
      transmissionService: MorseTransmissionService(
        flashlightController: TorchFlashlightController(),
      ),
      initialMessage: initialMessage,
      initialTimingUnitMs: initialTimingUnitMs,
      initialRepeatMode: initialRepeatMode,
      initialCustomRepeatCount: initialCustomRepeatCount,
      initialDelayBetweenRepeatsMs: initialDelayBetweenRepeatsMs,
    );
  }

}

class SendSessionScreen extends StatefulWidget {
  const SendSessionScreen({
    required this.controller,
    super.key,
  });

  final SendController controller;

  @override
  State<SendSessionScreen> createState() => _SendSessionScreenState();
}

class _SendSessionScreenState extends State<SendSessionScreen> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SendScreen(controller: widget.controller);
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5A36), Color(0xFFB12600)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledPanel extends StatelessWidget {
  const _DisabledPanel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD6D6D6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF9D9D9D),
                ),
          ),
        ],
      ),
    );
  }
}
