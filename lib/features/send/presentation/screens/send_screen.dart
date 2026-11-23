import 'package:flutter/material.dart';

import 'package:morse/features/history/domain/transmission_history_entry.dart';
import 'package:morse/features/library/domain/saved_message_template.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/morse_widgets.dart';
import '../../../../morse/domain/transmission_diagnostics.dart';
import '../../../../morse/domain/transmission_repeat_mode.dart';
import '../../../../morse/domain/transmission_state.dart';
import '../send_controller.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({
    required this.controller,
    super.key,
  });

  final SendController controller;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  static const _presets = ['SOS', 'HELP', 'YES', 'NO', 'OK'];
  static const double _minUnitMs = 60;
  static const double _maxUnitMs = 600;

  late final TextEditingController _textController;

  SendController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: controller.message);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _showSavedMessageDialog({
    SavedMessageTemplate? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SavedMessageEditorDialog(
        existing: existing,
        initialMessage: existing?.messageText ?? controller.message,
        onSave: ({
          required String title,
          required String messageText,
        }) {
          return controller.saveCustomMessage(
            existingId: existing?.id,
            isFavorite: existing?.isFavorite ?? false,
            title: title,
            messageText: messageText,
          );
        },
      ),
    );
  }

  void _openSavedMessages() {
    showMorseSheet<void>(
      context: context,
      title: 'Saved messages',
      action: IconButton(
        tooltip: 'Add saved message',
        icon: const Icon(Icons.add_rounded),
        onPressed: controller.hasActiveTransmission
            ? null
            : () => _showSavedMessageDialog(),
      ),
      builder: (sheetContext, scroll) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoadingSavedMessages) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.savedMessages.isEmpty) {
            return const _EmptySheet(
              icon: Icons.bookmark_outline_rounded,
              text: 'No saved messages yet.',
            );
          }
          final enabled = !controller.hasActiveTransmission;
          return ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: controller.savedMessages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final template = controller.savedMessages[i];
              return _SavedMessageTile(
                template: template,
                isSelected: controller.message == template.messageText,
                enabled: enabled,
                onToggleFavorite: () =>
                    controller.toggleSavedMessageFavorite(template),
                onUse: () {
                  controller.applySavedMessage(template);
                  Navigator.of(sheetContext).pop();
                },
                onSend: () {
                  Navigator.of(sheetContext).pop();
                  controller.sendSavedMessage(template);
                },
                onEdit: template.isBuiltIn
                    ? null
                    : () => _showSavedMessageDialog(existing: template),
                onDelete: template.isBuiltIn
                    ? null
                    : () => controller.deleteSavedMessage(template),
              );
            },
          );
        },
      ),
    );
  }

  void _openHistory() {
    showMorseSheet<void>(
      context: context,
      title: 'Recent',
      action: IconButton(
        tooltip: 'Refresh history',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: controller.refreshHistory,
      ),
      builder: (sheetContext, scroll) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.recentHistory.isEmpty) {
            return const _EmptySheet(
              icon: Icons.history_rounded,
              text: 'Nothing sent yet.',
            );
          }
          final enabled = !controller.hasActiveTransmission;
          return ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: controller.recentHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = controller.recentHistory[i];
              return _HistoryTile(
                entry: entry,
                enabled: enabled,
                onPopulate: () {
                  controller.populateFromHistoryEntry(entry);
                  Navigator.of(sheetContext).pop();
                },
                onResend: () {
                  Navigator.of(sheetContext).pop();
                  controller.resendHistoryEntry(entry);
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (_textController.text != controller.message) {
          _textController.value = TextEditingValue(
            text: controller.message,
            selection: TextSelection.collapsed(
              offset: controller.message.length,
            ),
          );
        }

        final busy = controller.hasActiveTransmission;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SEND'),
            actions: [
              IconButton(
                key: const Key('send-open-saved'),
                onPressed: _openSavedMessages,
                icon: const Icon(Icons.bookmark_outline_rounded),
                tooltip: 'Saved messages',
              ),
              IconButton(
                key: const Key('send-open-history'),
                onPressed: _openHistory,
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Recent',
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                color: AppTheme.surfaceRaised,
                onSelected: (value) {
                  if (value == 'debug') controller.toggleDebugOverlay();
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: 'debug',
                    checked: controller.debugOverlayEnabled,
                    child: const Text('Debug overlay'),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: _ActionBar(controller: controller),
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    ValueListenableBuilder<TransmissionState>(
                      valueListenable: controller.transmissionStateListenable,
                      builder: (context, state, _) =>
                          _LampPanel(transmissionState: state),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel(
                            'Message',
                            trailing: TextButton.icon(
                              onPressed:
                                  busy ? null : () => _showSavedMessageDialog(),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.bookmark_add_outlined,
                                size: 18,
                              ),
                              label: const Text('Save'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const Key('send-message-field'),
                            controller: _textController,
                            enabled: !busy,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Type a message',
                            ),
                            onChanged: controller.updateMessage,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final preset in _presets)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(preset),
                                      selected: controller.message == preset,
                                      onSelected: busy
                                          ? null
                                          : (_) =>
                                              controller.applyPreset(preset),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _MorsePreview(controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuickRow(
                      savedCount: controller.savedMessages.length,
                      historyCount: controller.recentHistory.length,
                      onSaved: _openSavedMessages,
                      onHistory: _openHistory,
                    ),
                    const SizedBox(height: 12),
                    _TimingPanel(
                      controller: controller,
                      minUnitMs: _minUnitMs,
                      maxUnitMs: _maxUnitMs,
                    ),
                    if (controller.statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.statusMessage!,
                        style: TextStyle(
                          color: busy
                              ? AppTheme.highlight
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (controller.debugOverlayEnabled)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ValueListenableBuilder<TransmissionDiagnostics>(
                      valueListenable: controller.diagnosticsListenable,
                      builder: (context, diagnostics, _) {
                        return _DebugOverlay(
                          diagnostics: diagnostics,
                          controller: controller,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact lamp that mirrors the flashlight, with live status.
class _LampPanel extends StatelessWidget {
  const _LampPanel({required this.transmissionState});

  final TransmissionState transmissionState;

  @override
  Widget build(BuildContext context) {
    final on = transmissionState.isLightOn;
    final active = transmissionState.isActive;
    final total = transmissionState.totalRepeats;
    final repeatLabel = !active
        ? null
        : total == null
            ? 'Round ${transmissionState.currentRepeat} · repeating'
            : 'Round ${transmissionState.currentRepeat} of $total';

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: on
                    ? const [
                        AppTheme.lamp,
                        Color(0xFFFFB347),
                        Color(0xFF3A2405)
                      ]
                    : const [
                        Color(0xFF1C1F23),
                        Color(0xFF121417),
                        AppTheme.surface
                      ],
                stops: const [0.2, 0.6, 1],
              ),
              border: Border.all(
                color: active ? AppTheme.emergency : AppTheme.border,
                width: on ? 3 : 1.5,
              ),
              boxShadow: [
                if (on)
                  BoxShadow(
                    color: AppTheme.highlight.withValues(alpha: 0.55),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
              ],
            ),
            child: Icon(
              Icons.flashlight_on_rounded,
              size: 30,
              color: on ? const Color(0xFF2A1600) : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: active ? AppTheme.highlight : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  repeatLabel ??
                      (transmissionState.status == TransmissionStatus.error
                          ? 'Check flashlight permission and try again.'
                          : 'Point the back of your phone at the receiver.'),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
                if (transmissionState.isWaitingBetweenRepeats)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Pause before next round',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _title() {
    switch (transmissionState.status) {
      case TransmissionStatus.idle:
        return 'Ready';
      case TransmissionStatus.transmitting:
        return 'Transmitting';
      case TransmissionStatus.paused:
        return 'Paused';
      case TransmissionStatus.stopped:
        return 'Stopped';
      case TransmissionStatus.error:
        return 'Flashlight error';
    }
  }
}

class _MorsePreview extends StatelessWidget {
  const _MorsePreview({required this.controller});

  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final translation = controller.translation;
    final preview = translation.morsePreview;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Morse'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 96),
            child: SingleChildScrollView(
              child: preview.isEmpty
                  ? const Text(
                      'Nothing to send yet.',
                      style: TextStyle(color: AppTheme.textMuted),
                    )
                  : Semantics(
                      label: preview,
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 10,
                        children: [
                          for (final word in translation.words)
                            if (word.letters.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: [
                                  for (final letter in word.letters)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        MorseGlyphs(letter.symbols, unit: 6),
                                        const SizedBox(height: 4),
                                        Text(
                                          letter.character,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                        ],
                      ),
                    ),
            ),
          ),
          if (translation.unsupportedCharacters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Skipped: ${translation.unsupportedCharacters.join(' ')}',
              style: const TextStyle(color: AppTheme.emergency, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Saved + recent stay as two small buttons; their lists open in sheets.
class _QuickRow extends StatelessWidget {
  const _QuickRow({
    required this.savedCount,
    required this.historyCount,
    required this.onSaved,
    required this.onHistory,
  });

  final int savedCount;
  final int historyCount;
  final VoidCallback onSaved;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickButton(
            key: const Key('send-saved-tile'),
            icon: Icons.bookmark_outline_rounded,
            label: 'Saved',
            count: savedCount,
            onTap: onSaved,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickButton(
            key: const Key('send-history-tile'),
            icon: Icons.history_rounded,
            label: 'Recent',
            count: historyCount,
            onTap: onHistory,
          ),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusM);
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.highlight),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.expand_less_rounded,
                size: 20,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speed + repeat settings, folded away by default.
class _TimingPanel extends StatelessWidget {
  const _TimingPanel({
    required this.controller,
    required this.minUnitMs,
    required this.maxUnitMs,
  });

  final SendController controller;
  final double minUnitMs;
  final double maxUnitMs;

  @override
  Widget build(BuildContext context) {
    final busy = controller.hasActiveTransmission;
    final repeatSummary = switch (controller.repeatMode) {
      TransmissionRepeatMode.once => 'once',
      TransmissionRepeatMode.forever => 'repeat forever',
      TransmissionRepeatMode.customCount => '×${controller.customRepeatCount}',
    };

    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('send-timing'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          iconColor: AppTheme.textSecondary,
          collapsedIconColor: AppTheme.textMuted,
          leading: const Icon(Icons.tune_rounded, color: AppTheme.highlight),
          title: const Text(
            'Speed & repeat',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${controller.unitMs} ms · $repeatSummary',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          children: [
            _SliderRow(
              label: 'Flash speed',
              value: '${controller.unitMs} ms',
              hint: _speedHint(controller.unitMs),
              slider: Slider(
                value: controller.unitMs.toDouble().clamp(minUnitMs, maxUnitMs),
                min: minUnitMs,
                max: maxUnitMs,
                divisions: ((maxUnitMs - minUnitMs) / 20).round(),
                label: '${controller.unitMs} ms',
                onChanged: busy ? null : controller.updateUnitMs,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in TransmissionRepeatMode.values)
                    ChoiceChip(
                      label: Text(switch (mode) {
                        TransmissionRepeatMode.once => 'Once',
                        TransmissionRepeatMode.forever => 'Forever',
                        TransmissionRepeatMode.customCount => 'Count',
                      }),
                      selected: controller.repeatMode == mode,
                      onSelected: busy
                          ? null
                          : (_) => controller.updateRepeatMode(mode),
                    ),
                ],
              ),
            ),
            if (controller.repeatMode ==
                TransmissionRepeatMode.customCount) ...[
              const SizedBox(height: 8),
              _SliderRow(
                label: 'Rounds',
                value: '${controller.customRepeatCount}',
                slider: Slider(
                  value: controller.customRepeatCount.toDouble().clamp(2, 20),
                  min: 2,
                  max: 20,
                  divisions: 18,
                  label: '${controller.customRepeatCount}',
                  onChanged: busy ? null : controller.updateCustomRepeatCount,
                ),
              ),
            ],
            if (controller.repeatMode != TransmissionRepeatMode.once) ...[
              const SizedBox(height: 8),
              _SliderRow(
                label: 'Pause between rounds',
                value: '${controller.delayBetweenRepeatsMs} ms',
                slider: Slider(
                  value: controller.delayBetweenRepeatsMs
                      .toDouble()
                      .clamp(0, 5000),
                  min: 0,
                  max: 5000,
                  divisions: 25,
                  label: '${controller.delayBetweenRepeatsMs} ms',
                  onChanged:
                      busy ? null : controller.updateDelayBetweenRepeatsMs,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _speedHint(int unitMs) {
    if (unitMs >= 300) return 'Easy to read by eye.';
    if (unitMs >= 180) return 'Medium — for practised readers.';
    return 'Fast — hard to read by eye.';
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        slider,
        if (hint != null)
          Text(
            hint!,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
      ],
    );
  }
}

/// START / STOP pinned to the bottom, above the system navigation.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller});

  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.transmissionState;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: state.canStop
              ? SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('send-stop'),
                    onPressed: controller.stopTransmission,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.highlight,
                      side: const BorderSide(
                        color: AppTheme.highlight,
                        width: 1.6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('STOP'),
                  ),
                )
              : SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('send-start'),
                    onPressed:
                        state.canStart ? controller.startTransmission : null,
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    icon: const Icon(Icons.flashlight_on_rounded),
                    label: const Text('START'),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptySheet extends StatelessWidget {
  const _EmptySheet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _SavedMessageTile extends StatelessWidget {
  const _SavedMessageTile({
    required this.template,
    required this.isSelected,
    required this.enabled,
    required this.onToggleFavorite,
    required this.onUse,
    required this.onSend,
    this.onEdit,
    this.onDelete,
  });

  final SavedMessageTemplate template;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onToggleFavorite;
  final VoidCallback onUse;
  final VoidCallback onSend;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: isSelected ? AppTheme.emergency : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onUse : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (template.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppTheme.highlight,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          template.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.messageText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send now',
            onPressed: enabled ? onSend : null,
            icon: const Icon(
              Icons.flashlight_on_rounded,
              color: AppTheme.emergency,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            color: AppTheme.surfaceMuted,
            enabled: enabled,
            onSelected: (v) {
              switch (v) {
                case 'use':
                  onUse();
                case 'fav':
                  onToggleFavorite();
                case 'edit':
                  onEdit?.call();
                case 'delete':
                  onDelete?.call();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'use', child: Text('Use')),
              PopupMenuItem(
                value: 'fav',
                child: Text(template.isFavorite ? 'Unfavorite' : 'Favorite'),
              ),
              if (onEdit != null)
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (onDelete != null)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.enabled,
    required this.onPopulate,
    required this.onResend,
  });

  final TransmissionHistoryEntry entry;
  final bool enabled;
  final VoidCallback onPopulate;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final t = entry.timestamp.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final when =
        '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
    final repeat = switch (entry.repeatMode) {
      'customCount' => '×${entry.repeatCount}',
      'forever' => 'forever',
      _ => 'once',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onPopulate : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.messageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$when · ${entry.timingUnitMs} ms · $repeat',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Use',
            onPressed: enabled ? onPopulate : null,
            icon: const Icon(Icons.edit_note_rounded),
          ),
          IconButton(
            tooltip: 'Send again',
            onPressed: enabled ? onResend : null,
            icon: const Icon(
              Icons.replay_rounded,
              color: AppTheme.emergency,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMessageEditorDialog extends StatefulWidget {
  const _SavedMessageEditorDialog({
    required this.initialMessage,
    required this.onSave,
    this.existing,
  });

  final SavedMessageTemplate? existing;
  final String initialMessage;
  final Future<bool> Function({
    required String title,
    required String messageText,
  }) onSave;

  @override
  State<_SavedMessageEditorDialog> createState() =>
      _SavedMessageEditorDialogState();
}

class _SavedMessageEditorDialogState extends State<_SavedMessageEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _messageController = TextEditingController(
      text: widget.initialMessage,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) {
      return;
    }

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      setState(() {
        _errorText = 'Title and message are required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final didSave = await widget.onSave(
      title: title,
      messageText: message,
    );

    if (!mounted) {
      return;
    }

    if (!didSave) {
      setState(() {
        _isSaving = false;
        _errorText = 'Unable to save message locally.';
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null ? 'Save message' : 'Edit saved message',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'Message text',
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(
                color: AppTheme.emergency,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          child: Text(_isSaving ? 'SAVING…' : 'SAVE'),
        ),
      ],
    );
  }
}

class _DebugOverlay extends StatelessWidget {
  const _DebugOverlay({
    required this.diagnostics,
    required this.controller,
  });

  final TransmissionDiagnostics diagnostics;
  final SendController controller;

  @override
  Widget build(BuildContext context) {
    final repeatLabel = diagnostics.totalRepeats == null
        ? '${diagnostics.currentRepeat}/forever'
        : '${diagnostics.currentRepeat}/${diagnostics.totalRepeats}';

    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xDD0A0A0A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DEBUG',
                style: TextStyle(
                  color: AppTheme.highlight,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              _DebugRow(label: 'State', value: diagnostics.status.name),
              _DebugRow(label: 'Symbol', value: diagnostics.currentSymbol),
              _DebugRow(label: 'Phase', value: diagnostics.currentPhase),
              _DebugRow(
                label: 'Duration',
                value: '${diagnostics.currentDurationMs} ms',
              ),
              _DebugRow(
                label: 'Unit',
                value: '${diagnostics.timingUnitMs} ms',
              ),
              _DebugRow(label: 'Repeat', value: repeatLabel),
              _DebugRow(
                label: 'Elapsed',
                value: '${diagnostics.elapsedMs} ms',
              ),
              _DebugRow(
                label: 'Listeners',
                value: '${controller.activeListenerCount}',
              ),
              _DebugRow(
                label: 'Controllers',
                value: '${controller.activeControllerInstances}',
              ),
              _DebugRow(
                label: 'Sessions',
                value: '${controller.activeTransmissionServiceInstances}',
              ),
              _DebugRow(
                label: 'Last Err',
                value: controller.lastError ?? '-',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
