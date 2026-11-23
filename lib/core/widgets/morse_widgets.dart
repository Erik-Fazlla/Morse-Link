import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded panel used for every grouped block of UI.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

/// Small uppercase label above a block.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Trailing keeps its natural width; the label gets what is left and
    // stays on one line (never wraps letter-by-letter at big text sizes).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Draws a dot/dash code ('.-..') as lamp-coloured pills — the app's
/// visual signature.
class MorseGlyphs extends StatelessWidget {
  const MorseGlyphs(
    this.code, {
    this.unit = 10,
    this.color = AppTheme.highlight,
    this.letterGap,
    super.key,
  });

  /// Dots, dashes, and spaces (a space is a letter gap).
  final String code;
  final double unit;
  final Color color;
  final double? letterGap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final ch in code.split('')) {
      if (ch == ' ') {
        children.add(SizedBox(width: letterGap ?? unit * 1.6));
        continue;
      }
      final isDash = ch == '-';
      children.add(
        Container(
          width: isDash ? unit * 3 : unit,
          height: unit,
          margin: EdgeInsets.symmetric(horizontal: unit * 0.3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(unit),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: unit * 0.9,
              ),
            ],
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Opens a bottom sheet that starts at [initialSize] of the screen and can
/// be dragged up to [maxSize] — never a full-page takeover.
Future<T?> showMorseSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext, ScrollController) builder,
  Widget? action,
  double initialSize = 0.55,
  double maxSize = 0.85,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        minChildSize: 0.3,
        maxChildSize: maxSize,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (action != null) action,
                  ],
                ),
              ),
              Expanded(child: builder(context, scrollController)),
            ],
          );
        },
      );
    },
  );
}
