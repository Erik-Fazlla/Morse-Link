import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/morse_widgets.dart';
import '../../morse/domain/morse_alphabet.dart';
import 'manual_keyer_controller.dart';

/// Owns one [ManualKeyerController] for the session.
class ManualReceiveSessionScreen extends StatefulWidget {
  const ManualReceiveSessionScreen({super.key});

  @override
  State<ManualReceiveSessionScreen> createState() =>
      _ManualReceiveSessionScreenState();
}

class _ManualReceiveSessionScreenState
    extends State<ManualReceiveSessionScreen> {
  final ManualKeyerController _controller = ManualKeyerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ManualReceiveScreen(controller: _controller);
}

/// Receive by eye: watch the other phone's flashes and key each one in.
/// Short flash = DOT, long flash = DASH.
class ManualReceiveScreen extends StatelessWidget {
  const ManualReceiveScreen({required this.controller, super.key});

  final ManualKeyerController controller;

  Future<void> _copy(BuildContext context) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('RECEIVE'),
            actions: [
              IconButton(
                tooltip: 'How it works',
                icon: const Icon(Icons.help_outline_rounded),
                onPressed: () => _showHelp(context),
              ),
              IconButton(
                tooltip: 'Copy message',
                icon: const Icon(Icons.copy_rounded),
                onPressed:
                    controller.text.isEmpty ? null : () => _copy(context),
              ),
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: controller.text.isEmpty && controller.symbols.isEmpty
                    ? null
                    : controller.clear,
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  Expanded(child: _MessagePanel(controller: controller)),
                  const SizedBox(height: 12),
                  _EditRow(controller: controller),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        Expanded(
                          child: _KeyButton(
                            key: const Key('keyer-dot'),
                            label: 'DOT',
                            hint: 'short flash',
                            glyph: '.',
                            onTap: controller.dot,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KeyButton(
                            key: const Key('keyer-dash'),
                            label: 'DASH',
                            hint: 'long flash',
                            glyph: '-',
                            onTap: controller.dash,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelp(BuildContext context) {
    showMorseSheet<void>(
      context: context,
      title: 'Reading flashes',
      initialSize: 0.6,
      builder: (context, scroll) {
        final entries = kMorseAlphabet.entries
            .where((e) => RegExp(r'[A-Z0-9]').hasMatch(e.key))
            .toList();
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const _HelpLine(
              icon: Icons.circle,
              text: 'Short flash → tap DOT.  Long flash (about 3× longer) '
                  '→ tap DASH.',
            ),
            const _HelpLine(
              icon: Icons.keyboard_return_rounded,
              text: 'Short dark pause → tap LETTER to finish the letter.',
            ),
            const _HelpLine(
              icon: Icons.timer_rounded,
              text: 'Auto gap on: stop tapping for about 1.5 seconds and the '
                  'letter finishes by itself — no LETTER tap needed. Best '
                  'for slow senders.',
            ),
            const _HelpLine(
              icon: Icons.space_bar_rounded,
              text: 'Long dark pause → tap SPACE to start a new word.',
            ),
            const _HelpLine(
              icon: Icons.speed_rounded,
              text: 'Ask the sender to use a slow speed (300 ms or more) '
                  'so every flash is easy to tell apart.',
            ),
            const SizedBox(height: 12),
            const SectionLabel('Alphabet'),
            const SizedBox(height: 10),
            // Three equal columns that always fill the sheet width; glyphs
            // shrink to fit their tile instead of spilling out (long codes
            // like 0 or J, or large system text sizes).
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final tileWidth = (constraints.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final e in entries)
                      Container(
                        key: Key('alphabet-${e.key}'),
                        width: tileWidth,
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  e.key,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: MorseGlyphs(e.value, unit: 5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.controller});

  final ManualKeyerController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.pendingLetter;
    final symbols = controller.symbols;
    final candidates = controller.candidates.take(8).toList();

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            'Message',
            trailing: _AutoGapToggle(
              value: controller.autoCommitEnabled,
              onChanged: (v) => controller.autoCommitEnabled = v,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                reverse: true,
                child: SizedBox(
                  width: double.infinity,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: controller.text),
                        if (pending != null)
                          TextSpan(
                            text: pending,
                            style: const TextStyle(color: AppTheme.highlight),
                          ),
                        const TextSpan(
                          text: '▍',
                          style: TextStyle(color: AppTheme.emergency),
                        ),
                      ],
                    ),
                    key: const Key('keyer-text'),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (controller.text.isEmpty && symbols.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Watch the other phone. Tap DOT for a short flash, '
                'DASH for a long one.',
                style: TextStyle(color: AppTheme.textMuted, height: 1.4),
              ),
            ),
          const Divider(height: 20),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: symbols.isEmpty
                      ? const Text(
                          'Current letter',
                          style: TextStyle(color: AppTheme.textMuted),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MorseGlyphs(symbols, unit: 12),
                        ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pending != null
                        ? AppTheme.highlight.withValues(alpha: 0.14)
                        : AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: pending != null
                          ? AppTheme.highlight
                          : symbols.isEmpty
                              ? AppTheme.border
                              : AppTheme.emergency,
                    ),
                  ),
                  child: Text(
                    pending ?? (symbols.isEmpty ? '–' : '?'),
                    key: const Key('keyer-pending'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: pending != null
                          ? AppTheme.highlight
                          : symbols.isEmpty
                              ? AppTheme.textMuted
                              : AppTheme.emergency,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: candidates.length > 1
                ? ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      const Text(
                        'Could be  ',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      for (final c in candidates)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            c.character,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  )
                : symbols.isNotEmpty && pending == null
                    ? const Text(
                        'No letter matches — tap ⌫ to fix',
                        style: TextStyle(
                          color: AppTheme.emergency,
                          fontSize: 13,
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.controller});

  final ManualKeyerController controller;

  @override
  Widget build(BuildContext context) {
    final hasAnything =
        controller.text.isNotEmpty || controller.symbols.isNotEmpty;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: OutlinedButton(
              key: const Key('keyer-backspace'),
              onPressed: hasAnything ? controller.backspace : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Icon(Icons.backspace_outlined, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const Key('keyer-letter'),
              onPressed: controller.canCommit ? controller.commitLetter : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppTheme.highlight,
                side: BorderSide(
                  color: controller.canCommit
                      ? AppTheme.highlight
                      : AppTheme.border,
                  width: 1.2,
                ),
              ),
              child: const _FitLabel(
                icon: Icons.keyboard_return_rounded,
                text: 'LETTER',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const Key('keyer-space'),
              onPressed: hasAnything ? controller.space : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const _FitLabel(
                icon: Icons.space_bar_rounded,
                text: 'SPACE',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + one-line label that shrinks instead of wrapping on narrow phones.
class _FitLabel extends StatelessWidget {
  const _FitLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Text(text, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}

/// One of the two big Morse keys. Fires on touch-down so fast sequences
/// keep up with the flashes.
class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.label,
    required this.hint,
    required this.glyph,
    required this.onTap,
    super.key,
  });

  final String label;
  final String hint;
  final String glyph;
  final VoidCallback onTap;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _down = false;

  void _press() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}, ${widget.hint}',
      onTap: _press,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _down = true);
          _press();
        },
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _down
                  ? const [Color(0xFF3A2A0E), Color(0xFF2A1D08)]
                  : const [AppTheme.surfaceRaised, AppTheme.surface],
            ),
            border: Border.all(
              color: _down ? AppTheme.highlight : AppTheme.border,
              width: _down ? 2 : 1.2,
            ),
            boxShadow: _down
                ? [
                    BoxShadow(
                      color: AppTheme.highlight.withValues(alpha: 0.25),
                      blurRadius: 24,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MorseGlyphs(widget.glyph, unit: 18),
              const SizedBox(height: 16),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact on/off pill for the auto letter gap. Narrower than a Switch so
/// the header fits on small phones with large system text.
class _AutoGapToggle extends StatelessWidget {
  const _AutoGapToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = value ? AppTheme.highlight : AppTheme.textMuted;
    return Semantics(
      toggled: value,
      label: 'Auto letter gap',
      child: Material(
        color: value
            ? AppTheme.highlight.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: value ? AppTheme.highlight : AppTheme.border),
        ),
        child: InkWell(
          key: const Key('keyer-auto-gap'),
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.timer_rounded : Icons.timer_off_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  value ? 'Auto gap on' : 'Auto gap off',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.highlight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
