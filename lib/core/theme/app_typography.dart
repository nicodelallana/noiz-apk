import 'package:flutter/material.dart';

/// Typography on Apple's text scale (Large Title 34 · Title 22 · Headline 17 ·
/// Body 17 · Subheadline 15 · Footnote 13 · Caption 12), set in Inter — the
/// closest licensable face to SF Pro on Android and the web. Tracking
/// tightens as size grows, like SF's optical sizes.
abstract final class AppTypography {
  /// Text cut (opsz 14) for everything up to ~22 pt.
  static const String fontFamily = 'Inter';

  /// Display cut (opsz 32) for countdowns and large titles.
  static const String displayFamily = 'InterDisplay';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Hero countdown ("12"), always tabular so digits don't jitter.
  static const TextStyle countdown = TextStyle(
    fontFamily: displayFamily,
    fontSize: 72,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.6,
    height: 1,
    fontFeatures: tabular,
  );

  /// Countdown in list rows and sheets.
  static const TextStyle countdownSmall = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1,
    fontFeatures: tabular,
  );

  /// Clock times ("23:05") and other figures inside text.
  static const TextStyle time = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    fontFeatures: tabular,
  );

  /// Material 3 [TextTheme] mapped onto the Apple scale.
  static TextTheme textTheme() {
    return const TextTheme(
      // Large Title
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.12,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
      ),

      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.12,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        height: 1.22,
      ),

      // Title 2 · Headline · Subheadline
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        height: 1.22,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.33,
      ),

      // Body · Callout · Footnote
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.4,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        height: 1.38,
      ),

      // Labels · Caption · Tab label
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.33,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.2,
      ),
    );
  }
}
