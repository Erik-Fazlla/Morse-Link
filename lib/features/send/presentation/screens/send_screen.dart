import 'package:flutter/material.dart';

import 'package:morse/features/history/domain/transmission_history_entry.dart';
import 'package:morse/features/library/domain/saved_message_template.dart';
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

  late final TextEditingController _textController;
  bool _savedMessagesExpanded = true;
  bool _historyExpanded = true;

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('SEND'),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: controller.toggleDebugOverlay,
                icon: Icon(
                  controller.debugOverlayEnabled
                      ? Icons.bug_report
                      : Icons.bug_report_outlined,
                ),
                tooltip: 'Toggle debug overlay',
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        child: Column(
                          children: [
                            Text(
                              'Transmission Indicator',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 18),
                            ValueListenableBuilder<TransmissionState>(
                              valueListenable:
                                  controller.transmissionStateListenable,
                              builder: (context, transmissionState, _) {
                                return _TransmissionIndicator(
                                  transmissionState: transmissionState,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Message',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: controller.hasActiveTransmission
                                      ? null
                                      : () => _showSavedMessageDialog(),
                                  icon: const Icon(Icons.bookmark_add_outlined),
                                  label: const Text('Save Current'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _textController,
                              enabled: !controller.hasActiveTransmission,
                              minLines: 4,
                              maxLines: 6,
                              textCapitalization:
                                  TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type emergency message',
                              ),
                              onChanged: controller.updateMessage,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Flash Speed',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${controller.unitMs} ms',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            Slider(
                              value: controller.unitMs.toDouble(),
                              min: 60,
                              max: 320,
                              divisions: 26,
                              label: '${controller.unitMs} ms',
                              onChanged: controller.hasActiveTransmission
                                  ? null
                                  : controller.updateUnitMs,
                            ),
                            Text(
                              'Base timing unit for dots, dashes, and spacing.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF9D9D9D),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repeat Mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _RepeatModeChip(
                                  label: 'Once',
                                  selected:
                                      controller.repeatMode ==
                                          TransmissionRepeatMode.once,
                                  enabled: !controller.hasActiveTransmission,
                                  onTap: () => controller.updateRepeatMode(
                                    TransmissionRepeatMode.once,
                                  ),
                                ),
                                _RepeatModeChip(
                                  label: 'Repeat Forever',
                                  selected:
                                      controller.repeatMode ==
                                          TransmissionRepeatMode.forever,
                                  enabled: !controller.hasActiveTransmission,
                                  onTap: () => controller.updateRepeatMode(
                                    TransmissionRepeatMode.forever,
                                  ),
                                ),
                                _RepeatModeChip(
                                  label: 'Custom Count',
                                  selected:
                                      controller.repeatMode ==
                                          TransmissionRepeatMode.customCount,
                                  enabled: !controller.hasActiveTransmission,
                                  onTap: () => controller.updateRepeatMode(
                                    TransmissionRepeatMode.customCount,
                                  ),
                                ),
                              ],
                            ),
                            if (controller.repeatMode ==
                                TransmissionRepeatMode.customCount) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Repeat Count',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${controller.customRepeatCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              Slider(
                                value:
                                    controller.customRepeatCount.toDouble(),
                                min: 2,
                                max: 20,
                                divisions: 18,
                                label: '${controller.customRepeatCount}',
                                onChanged: controller.hasActiveTransmission
                                    ? null
                                    : controller.updateCustomRepeatCount,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delay Between Repeats',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${controller.delayBetweenRepeatsMs} ms',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            Slider(
                              value: controller.delayBetweenRepeatsMs
                                  .toDouble(),
                              min: 0,
                              max: 5000,
                              divisions: 25,
                              label:
                                  '${controller.delayBetweenRepeatsMs} ms',
                              onChanged: controller.hasActiveTransmission
                                  ? null
                                  : controller.updateDelayBetweenRepeatsMs,
                            ),
                            Text(
                              'Applies after each full message while keeping Morse symbol timing exact.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF9D9D9D),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Presets',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final preset in _presets)
                                  ChoiceChip(
                                    label: Text(preset),
                                    selected: controller.message == preset,
                                    onSelected:
                                        controller.hasActiveTransmission
                                            ? null
                                            : (_) => controller.applyPreset(
                                                  preset,
                                                ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CollapsibleHeader(
                              title: 'Saved Messages',
                              subtitle: 'Quick populate or send emergency templates',
                              expanded: _savedMessagesExpanded,
                              trailing: IconButton(
                                onPressed: controller.hasActiveTransmission
                                    ? null
                                    : () => _showSavedMessageDialog(),
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Add custom saved message',
                              ),
                              onTap: () {
                                setState(() {
                                  _savedMessagesExpanded =
                                      !_savedMessagesExpanded;
                                });
                              },
                            ),
                            if (_savedMessagesExpanded) ...[
                              const SizedBox(height: 12),
                              if (controller.isLoadingSavedMessages)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (controller.savedMessages.isEmpty)
                                Text(
                                  'No saved messages available.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF9D9D9D),
                                      ),
                                )
                              else
                                Column(
                                  children: [
                                    for (final template
                                        in controller.savedMessages)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _SavedMessageCard(
                                          template: template,
                                          isSelected: controller.message ==
                                              template.messageText,
                                          enabled:
                                              !controller.hasActiveTransmission,
                                          onToggleFavorite: () => controller
                                              .toggleSavedMessageFavorite(
                                                template,
                                              ),
                                          onUse: () => controller
                                              .applySavedMessage(template),
                                          onSend: () => controller
                                              .sendSavedMessage(template),
                                          onEdit: template.isBuiltIn
                                              ? null
                                              : () => _showSavedMessageDialog(
                                                    existing: template,
                                                  ),
                                          onDelete: template.isBuiltIn
                                              ? null
                                              : () => controller
                                                  .deleteSavedMessage(template),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CollapsibleHeader(
                              title: 'Recent History',
                              subtitle: 'Last 10 successful transmissions',
                              expanded: _historyExpanded,
                              trailing: IconButton(
                                onPressed: controller.refreshHistory,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh history',
                              ),
                              onTap: () {
                                setState(() {
                                  _historyExpanded = !_historyExpanded;
                                });
                              },
                            ),
                            if (_historyExpanded) ...[
                              const SizedBox(height: 12),
                              if (controller.isLoadingHistory)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (controller.recentHistory.isEmpty)
                                Text(
                                  'No recent transmissions yet.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF9D9D9D),
                                      ),
                                )
                              else
                                Column(
                                  children: [
                                    for (final entry in controller.recentHistory)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: _HistoryCard(
                                          entry: entry,
                                          enabled:
                                              !controller.hasActiveTransmission,
                                          onPopulate: () => controller
                                              .populateFromHistoryEntry(entry),
                                          onResend: () => controller
                                              .resendHistoryEntry(entry),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Morse Preview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              controller.translation.morsePreview.isEmpty
                                  ? 'No transmittable Morse yet.'
                                  : controller.translation.morsePreview,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            if (controller.translation.unsupportedCharacters
                                .isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Ignored unsupported characters: ${controller.translation.unsupportedCharacters.join(', ')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFFFC857),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.transmissionState.canStart
                                  ? controller.startTransmission
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5A36),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              child: const Text('START'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.transmissionState.canStop
                                  ? controller.stopTransmission
                                  : null,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                side: const BorderSide(
                                  color: Color(0xFFFFC857),
                                  width: 1.4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              child: const Text('STOP'),
                            ),
                          ),
                        ],
                      ),
                      if (controller.statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          controller.statusMessage!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: controller.hasActiveTransmission
                                    ? const Color(0xFFFFC857)
                                    : const Color(0xFFD7D7D7),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                      if (controller.hasActiveTransmission) ...[
                        const SizedBox(height: 10),
                        ValueListenableBuilder<TransmissionState>(
                          valueListenable:
                              controller.transmissionStateListenable,
                          builder: (context, transmissionState, _) {
                            final total = transmissionState.totalRepeats;
                            final label = total == null
                                ? 'Repeat ${transmissionState.currentRepeat} / forever'
                                : 'Repeat ${transmissionState.currentRepeat} / $total';

                            return Text(
                              transmissionState.isWaitingBetweenRepeats
                                  ? '$label - standby'
                                  : label,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFFFFC857),
                                    fontWeight: FontWeight.w700,
                                  ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
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
      backgroundColor: const Color(0xFF111111),
      title: Text(
        widget.existing == null ? 'Save Custom Message' : 'Edit Saved Message',
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFF8A6B),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A36),
            foregroundColor: Colors.white,
          ),
          child: Text(_isSaving ? 'SAVING...' : 'SAVE'),
        ),
      ],
    );
  }
}

class _CollapsibleHeader extends StatelessWidget {
  const _CollapsibleHeader({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9D9D9D),
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFFD7D7D7),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMessageCard extends StatelessWidget {
  const _SavedMessageCard({
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFF5A36)
              : template.isFavorite
                  ? const Color(0xFFFFC857)
                  : const Color(0xFF262626),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                icon: Icon(
                  template.isFavorite ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFC857),
                ),
                tooltip: 'Favorite',
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: enabled ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                ),
            ],
          ),
          Text(
            template.messageText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFD7D7D7),
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 320;
              if (shouldStack) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: enabled ? onUse : null,
                        child: const Text('USE'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: enabled ? onSend : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A36),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('SEND'),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled ? onUse : null,
                      child: const Text('USE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: enabled ? onSend : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A36),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('SEND'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
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
    final timestamp = entry.timestamp.toLocal();
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final repeatLabel = entry.repeatMode == 'customCount'
        ? 'custom x${entry.repeatCount}'
        : entry.repeatMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.messageText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${timestamp.year}-$month-$day $hour:$minute',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D9D9D),
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _HistoryMetaChip(label: 'Unit ${entry.timingUnitMs} ms'),
              _HistoryMetaChip(label: 'Repeat $repeatLabel'),
              _HistoryMetaChip(
                label: 'Delay ${entry.delayBetweenRepeatsMs} ms',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final shouldStack = constraints.maxWidth < 340;
              if (shouldStack) {
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: enabled ? onPopulate : null,
                        child: const Text('POPULATE'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: enabled ? onResend : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A36),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('RESEND'),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled ? onPopulate : null,
                      child: const Text('POPULATE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: enabled ? onResend : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5A36),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('RESEND'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryMetaChip extends StatelessWidget {
  const _HistoryMetaChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFD7D7D7),
            ),
      ),
    );
  }
}

class _RepeatModeChip extends StatelessWidget {
  const _RepeatModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: child,
    );
  }
}

class _TransmissionIndicator extends StatelessWidget {
  const _TransmissionIndicator({
    required this.transmissionState,
  });

  final TransmissionState transmissionState;

  @override
  Widget build(BuildContext context) {
    final isTransmitting = transmissionState.isActive;
    final isLightOn = transmissionState.isLightOn;
    final glowColor =
        isLightOn ? const Color(0xFFFFC857) : const Color(0xFF2A2A2A);
    final coreColor =
        isLightOn ? const Color(0xFFFFF0B3) : const Color(0xFF090909);
    final ringColor =
        isTransmitting ? const Color(0xFFFF5A36) : const Color(0xFF383838);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                coreColor,
                isLightOn ? const Color(0xFFFFB347) : const Color(0xFF121212),
                const Color(0xFF050505),
              ],
              stops: const [0.18, 0.52, 1],
            ),
            border: Border.all(
              color: ringColor,
              width: isLightOn ? 4 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isLightOn ? 0.55 : 0.08),
                blurRadius: isLightOn ? 36 : 10,
                spreadRadius: isLightOn ? 10 : 1,
              ),
              BoxShadow(
                color: const Color(0xFFFF5A36)
                    .withOpacity(isTransmitting ? 0.18 : 0.0),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isLightOn ? 1 : 0.45,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flashlight_on_rounded,
                    color: isLightOn
                        ? const Color(0xFF2A1600)
                        : const Color(0xFF6A6A6A),
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLightOn ? 'ON' : 'OFF',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: isLightOn
                              ? const Color(0xFF2A1600)
                              : const Color(0xFFB8B8B8),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _statusLabel(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLightOn
                    ? const Color(0xFFFFC857)
                    : const Color(0xFF9D9D9D),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _statusLabel() {
    switch (transmissionState.status) {
      case TransmissionStatus.idle:
        return 'Waiting for transmission';
      case TransmissionStatus.transmitting:
        return 'Synchronized to live timing engine';
      case TransmissionStatus.paused:
        return 'Transmission paused';
      case TransmissionStatus.stopped:
        return 'Transmission stopped';
      case TransmissionStatus.error:
        return 'Transmission error';
    }
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DEBUG',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFFC857),
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
            style: const TextStyle(color: Color(0xFF9D9D9D)),
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
