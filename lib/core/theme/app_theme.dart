import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF050505);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceMuted = Color(0xFF1A1A1A);
  static const Color emergency = Color(0xFFFF5A36);
  static const Color highlight = Color(0xFFFFC857);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9D9D9D);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: emergency,
        secondary: highlight,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF262626)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: emergency, width: 1.4),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: emergency,
        thumbColor: emergency,
        inactiveTrackColor: surfaceMuted,
        overlayColor: emergency.withOpacity(0.18),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceMuted,
        selectedColor: emergency,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
