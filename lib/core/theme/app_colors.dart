import 'package:flutter/material.dart';

/// Refined color palette for Noiz (Bizkaia Transit).
///
/// Designed with high-contrast ratios for outdoor readability in Basque weather,
/// clean modern aesthetics inspired by Transit, and dynamic mode accents.
abstract final class AppColors {
  // ── Metro Bilbao Mode (Red/Slate) ──────────────────────────────────────
  static const Color metroRed = Color(0xFFE2001A);
  static const Color metroRedDark = Color(0xFFB30014);
  static const Color metroRedLight = Color(0xFFFF4D5E);
  static const Color metroL2 = Color(0xFF1E293B);

  // ── Bus Mode (Bizkaibus / Bilbobus Emerald) ─────────────────────────────
  static const Color busGreen = Color(0xFF00843D);
  static const Color bizkaibusGreen = busGreen;
  static const Color busGreenDark = Color(0xFF005E2B);
  static const Color busGreenLight = Color(0xFF10B981);
  static const Color bilbobusRed = Color(0xFFE11D48);

  // ── Core Brand ──────────────────────────────────────────────────────────
  static const Color brandNavy = Color(0xFF0F172A);
  static const Color brandBlue = Color(0xFF0052CC);

  // ── High-Contrast Neutrals ──────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F5F9);

  // ── Typography & Content ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Ultra-readable dark slate
  static const Color textSecondary = Color(0xFF475569); // Clear secondary slate
  static const Color textMuted = Color(0xFF94A3B8); // Subtle label
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Borders & Dividers ──────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFFCBD5E1);

  // ── Status Indicators ───────────────────────────────────────────────────
  static const Color livePulse = Color(0xFF10B981); // Emerald pulse for incoming
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // ── Backward-compatible Aliases ─────────────────────────────────────────
  static const Color primary = metroRed;
  static const Color primaryLight = metroRedLight;
  static const Color primaryDark = metroRedDark;
  static const Color secondary = busGreen;
  static const Color secondaryLight = busGreenLight;
  static const Color secondaryDark = busGreenDark;
  static const Color onSecondary = onPrimary;
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  static const Color surfaceVariant = surfaceSecondary;
  static const Color outline = borderFocus;
  static const Color outlineVariant = borderLight;
  static const Color darkAccent = metroL2;
  static const Color metroL1 = metroRed;
  static const Color bizkaibus = busGreen;
  static const Color renfe = Color(0xFF7C3AED);
}
