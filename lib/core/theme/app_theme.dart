import 'package:flutter/material.dart';

/// Team colour tokens, aligned with the web app's site.css (dark theme).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF111827);
  static const Color elevated = Color(0xFF1C2A3E);
  static const Color border = Color(0x1FFFFFFF);

  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFFA8B8CC);

  static const Color accent = Color(0xFF7C6DF8);
  static const Color cyan = Color(0xFF22D3EE);

  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
}

/// App-wide theme. Feature screens use Theme.of(context) instead of hard-coded colours;
/// only the Kahoot screens keep their own KahootColors palette.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.danger,
      onSurface: AppColors.textPrimary,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x2E818CF8), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.elevated,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
