import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/morse_widgets.dart';
import '../../../history/services/transmission_history_repository.dart';
import '../../../library/services/saved_message_repository.dart';
import '../../../morse/domain/transmission_repeat_mode.dart';
import '../../../morse/services/morse_translator.dart';
import '../../../morse/services/morse_transmission_service.dart';
import '../../../morse/services/timing_sequence_builder.dart';
import '../../../morse/services/torch_flashlight_controller.dart';
import '../../../protocol/services/communication_protocol_service.dart';
import '../../../receive/manual/manual_receive_screen.dart';
import '../send_controller.dart';
import 'send_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final TransmissionHistoryRepository _historyRepository =
      TransmissionHistoryRepository();
  static final SavedMessageRepository _savedMessageRepository =
      SavedMessageRepository();

  void _push(BuildContext context, WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Brand(),
                      const Spacer(),
                      const SizedBox(height: 32),
                      _ModeTile(
                        key: const Key('home-send'),
                        title: 'Send',
                        subtitle: 'Type a message. Your flashlight blinks it '
                            'in Morse.',
                        icon: Icons.flashlight_on_rounded,
                        code: '... . -. -..',
                        primary: true,
                        onTap: () => _push(
                          context,
                          (_) => SendSessionScreen(
                            controller: _buildSendController(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ModeTile(
                        key: const Key('home-receive'),
                        title: 'Receive',
                        subtitle: 'Watch their flashes and tap them in. '
                            'The app spells the message.',
                        icon: Icons.visibility_rounded,
                        code: '.-. . -.-.',
                        onTap: () => _push(
                          context,
                          (_) => const ManualReceiveSessionScreen(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _Tip(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SendController _buildSendController({
    String initialMessage = 'SOS',
    int initialTimingUnitMs = 300,
    TransmissionRepeatMode initialRepeatMode = TransmissionRepeatMode.once,
    int initialCustomRepeatCount = 3,
    int initialDelayBetweenRepeatsMs = 1500,
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

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MorseGlyphs('-- --- .-. ... .', unit: 7),
        const SizedBox(height: 22),
        Text(
          'MORSE',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                height: 1,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Talk with light when nothing else works.\nNo signal, no internet '
          'needed.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.code,
    required this.onTap,
    this.primary = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String code;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: primary
                ? const LinearGradient(
                    colors: [AppTheme.emergency, AppTheme.emergencyDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: primary ? null : AppTheme.surface,
            border: primary ? null : Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppTheme.highlight.withValues(alpha: 0.12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: primary ? Colors.white : AppTheme.highlight,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: primary
                            ? Colors.white.withValues(alpha: 0.88)
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MorseGlyphs(
                      code,
                      unit: 5,
                      color: primary
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.highlight.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: primary ? Colors.white : AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          size: 18,
          color: AppTheme.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reading by eye works best slow. Keep the flash speed at '
            '300 ms or more, and repeat the message.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}
