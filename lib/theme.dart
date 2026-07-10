import 'package:flutter/material.dart';

/// Welhof brand palette + shared theme.
/// Colors taken from the Welhof Hyva theme: primary blue #0057bf,
/// accent red #e40033 (the logo's ellipse).
class WelhofColors {
  static const Color brand = Color(0xFF0057BF); // Welhof blue
  static const Color brandDark = Color(0xFF004A9F); // darker blue
  static const Color accent = Color(0xFFE40033); // Welhof red
  static const Color surface = Color(0xFFF4F6F9);
  static const Color ink = Color(0xFF13233A);
}

ThemeData buildWelhofTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: WelhofColors.brand,
    primary: WelhofColors.brand,
    secondary: WelhofColors.accent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: WelhofColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: WelhofColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WelhofColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WelhofColors.brand, width: 2),
      ),
    ),
  );
}
