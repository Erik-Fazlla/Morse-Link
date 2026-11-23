import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens. Concept: a signal lamp at night — near-black field,
/// warm amber for light (dots, flashes), signal red-orange for actions.
class AppTheme {
  // Surfaces
  static const Color background = Color(0xFF07080A);
  static const Color surface = Color(0xFF111316);
  static const Color surfaceRaised = Color(0xFF181B1F);
  static const Color surfaceMuted = Color(0xFF1F2328);
  static const Color border = Color(0xFF262A30);

  // Signal colours
  static const Color emergency = Color(0xFFFF5A36);
  static const Color emergencyDeep = Color(0xFFC43A16);
  static const Color highlight = Color(0xFFFFC857);
  static const Color lamp = Color(0xFFFFE6A3);
  static const Color success = Color(0xFF6BD49A);

  // Text
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFFC9CDD3);
  static const Color textMuted = Color(0xFF8A9099);

  static const double radiusL = 24;
  static const double radiusM = 16;
  static const double radiusS = 12;

  /// Monospace style for dots and dashes.
  static const TextStyle morse = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['RobotoMono', 'Courier New', 'Courier'],
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: highlight,
  );

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final text = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: const ColorScheme.dark(
        primary: emergency,
        secondary: highlight,
        surface: surface,
        surfaceContainerHighest: surfaceMuted,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        outline: border,
      ),
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusL)),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceMuted,
        contentTextStyle: TextStyle(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: emergency, width: 1.4),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emergency,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceMuted,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: highlight),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: emergency,
        thumbColor: emergency,
        inactiveTrackColor: surfaceMuted,
        overlayColor: emergency.withValues(alpha: 0.18),
        trackHeight: 4,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceRaised,
        selectedColor: emergency,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        side: const BorderSide(color: border),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? emergency : surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}
