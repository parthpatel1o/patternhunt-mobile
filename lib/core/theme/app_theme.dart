import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  /// Lavender (`AppColors.primary`) is a background / selected-fill only.
  /// Never use it as text, icon, or outline color on white / light surfaces.
  /// Interactive accents on light backgrounds use dark purple (`AppColors.accent`).
  static ThemeData light() {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.background,
        onSurface: AppColors.foreground,
        // Dark purple for Material widgets that paint foreground on light surfaces
        // (TextButton, Switch, OutlinedButton, progress, focused labels, etc.).
        primary: AppColors.accent,
        onPrimary: AppColors.accentForeground,
        // Lavender only as a filled container, with dark content on top.
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.foreground,
        secondary: AppColors.accent,
        onSecondary: AppColors.accentForeground,
        secondaryContainer: AppColors.primaryStrong,
        onSecondaryContainer: AppColors.foreground,
        error: AppColors.destructive,
        onError: AppColors.accentForeground,
        outline: AppColors.border,
      ),
      textTheme: textTheme.apply(bodyColor: AppColors.foreground, displayColor: AppColors.foreground),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.accent,
        iconTheme: const IconThemeData(color: AppColors.accent),
        actionsIconTheme: const IconThemeData(color: AppColors.accent),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.accent,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primary,
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: AppColors.accent),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        labelStyle: const TextStyle(color: AppColors.muted),
        floatingLabelStyle: const TextStyle(color: AppColors.accent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentForeground,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.muted,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.card;
          return AppColors.card;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.accentForeground),
        side: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.border,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentForeground,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }
}
