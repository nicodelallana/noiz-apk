import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';

/// Material 3 theme configuration for Barik with dynamic operator accents
/// and Garraio midnight dark theme baseline.
abstract final class AppTheme {
  /// Builds theme based on active operator color accent and mode.
  static ThemeData themeFor({
    bool isBus = false,
    Color? accentColor,
    bool isDark = true,
  }) {
    final textTheme = AppTypography.textTheme();
    final primaryColor = accentColor ??
        (isBus ? AppColors.opBizkaibus : AppColors.opMetroBilbao);

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: isBus ? AppColors.opMetroBilbao : AppColors.opBizkaibus,
      onSecondary: Colors.white,
      error: AppColors.disruptedRed,
      onError: Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface:
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      onSurfaceVariant:
          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      outline: isDark ? AppColors.darkBorderStrong : AppColors.lightBorder,
      outlineVariant:
          isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      // iOS slide on every platform: pushed screens paint their own aurora,
      // and Android's fade/zoom would fade the shell's glass with them.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Tabs are transparent so the shell's aurora shows through.
      scaffoldBackgroundColor: isDark
          ? Colors.transparent
          : AppColors.lightBackground,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ── Input ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurfaceSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Bottom Sheet ────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
