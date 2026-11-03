import 'package:flutter/material.dart';

class Palette {
  static const black = Color(0xFF000000);
  static const panel = Color(0xFF141414);
  static const raised = Color(0xFF1F1F1F);
  static const line = Color(0xFF2E2E2E);
  static const text = Color(0xFFEDEDED);
  static const textDim = Color(0xFF9A9A9A);
  static const accent = Color(0xFFFF8A00); // VLC-style orange
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.black,
    colorScheme: const ColorScheme.dark(
      primary: Palette.accent,
      secondary: Palette.accent,
      surface: Palette.panel,
      onSurface: Palette.text,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.panel,
      modalBackgroundColor: Palette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 3,
      activeTrackColor: Palette.accent,
      inactiveTrackColor: Colors.white24,
      secondaryActiveTrackColor: Colors.white38,
      thumbColor: Palette.accent,
      overlayColor: Palette.accent.withOpacity(0.18),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
  );
}
