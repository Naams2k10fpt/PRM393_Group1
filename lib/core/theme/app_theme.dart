import 'package:flutter/material.dart';

/// Team colour tokens, aligned with the web app's site.css (AuthKit Midnight Cathedral).
class AppDarkColors {
  AppDarkColors._();

  static const Color background = Color(0xFF05060F); // Midnight Canvas
  static const Color surface = Color(0xFF111827);    // Deep Glass Base
  static const Color elevated = Color(0xFF161C28);   // Elevated Glass Plate
  static const Color border = Color(0x1FBad7F7);     // Glass Edge Hairline

  static const Color textPrimary = Color(0xFFD1E4FA); // Frost Glow
  static const Color textMuted = Color(0xFFC7D3EA);   // Moon Mist

  static const Color accent = Color(0xFF663AF3); // Void Violet CTA
  static const Color cyan = Color(0xFF38BDF8);   // Blueprint Blue / Cyan Glow

  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
}

/// Team colour tokens for Light Theme.
class AppLightColors {
  AppLightColors._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color elevated = Color(0xFFF1F5F9);
  static const Color border = Color(0x1A0F172A);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569); // High-contrast Slate-600

  static const Color accent = Color(0xFF6366F1);
  static const Color cyan = Color(0xFF0284C7);

  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
}

/// Backward compatibility alias so existing code keeps compiling seamlessly.
typedef AppColors = AppDarkColors;

/// Extension to easily fetch theme-aware colors from BuildContext.
extension AppThemeContextExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get textPrimaryColor => isDark ? AppDarkColors.textPrimary : AppLightColors.textPrimary;
  Color get textMutedColor => isDark ? AppDarkColors.textMuted : AppLightColors.textMuted;
  Color get surfaceColor => isDark ? AppDarkColors.surface : AppLightColors.surface;
  Color get elevatedColor => isDark ? AppDarkColors.elevated : AppLightColors.elevated;
  Color get accentColor => isDark ? AppDarkColors.accent : AppLightColors.accent;
  Color get cyanColor => isDark ? AppDarkColors.cyan : AppLightColors.cyan;
}

/// App-wide theme. Feature screens use Theme.of(context) instead of hard-coded colours;
/// the live Kahoot game keeps its own dark palette.
class AppTheme {
  AppTheme._();

  /// Reactive notifier for the active theme mode across the app.
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.dark);

  /// Toggle between Dark Mode and Light Mode.
  static void toggleTheme() {
    themeModeNotifier.value =
        themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  /// Dark theme configuration.
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppDarkColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppDarkColors.accent,
      secondary: AppDarkColors.cyan,
      surface: AppDarkColors.surface,
      error: AppDarkColors.danger,
      onSurface: AppDarkColors.textPrimary,
      onSurfaceVariant: AppDarkColors.textMuted,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppDarkColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppDarkColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x2E818CF8), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDarkColors.elevated,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppDarkColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppDarkColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFB9A8FF)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB9A8FF),
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Color(0x33818CF8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: AppDarkColors.surface,
        elevation: 8,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x33818CF8), width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: AppDarkColors.textMuted,
        ),
      ),
    );
  }

  /// Light theme configuration matching the cyber-academic aesthetic in daylight mode.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppLightColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppLightColors.accent,
      secondary: AppLightColors.cyan,
      surface: AppLightColors.surface,
      error: AppLightColors.danger,
      onSurface: AppLightColors.textPrimary,
      onSurfaceVariant: AppLightColors.textMuted,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppLightColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppLightColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppLightColors.surface,
        elevation: 1,
        shadowColor: const Color(0x0D000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1F6366F1), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppLightColors.elevated,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppLightColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppLightColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46C7)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4F46C7),
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Color(0x336366F1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dialogTheme: DialogThemeData(
        backgroundColor: AppLightColors.surface,
        elevation: 8,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1F6366F1), width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppLightColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 15,
          color: AppLightColors.textMuted,
        ),
      ),
    );
  }
}
