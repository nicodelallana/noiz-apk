import 'package:flutter/material.dart';

/// Design tokens and color palette for Barik transit companion.
///
/// Implements deep dark midnight palette matching Garraio reference,
/// with per-operator accent colors and high-contrast status badges.
abstract final class AppColors {
  // ── Dark Theme Canvas (Garraio Midnight Baseline) ─────────────────────────
  static const Color darkBackground = Color(0xFF0B0D14);
  static const Color darkSurface = Color(0xFF151822);
  static const Color darkSurfaceElevated = Color(0xFF1C202D);
  static const Color darkBorder = Color(0x1AF5F7FF); // rgba(245, 247, 255, 0.10)
  static const Color darkBorderStrong = Color(0x29F5F7FF); // 0.16
  static const Color darkTextPrimary = Color(0xFFF5F7FF);
  static const Color darkTextSecondary = Color(0xFF9198AD);

  // ── Light Theme Fallback ──────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ── Status Indicators ─────────────────────────────────────────────────────
  static const Color realtimeGreen = Color(0xFF2BB081); // Live / En directo
  static const Color delayedAmber = Color(0xFFFFB84D);  // +X min delay
  static const Color disruptedRed = Color(0xFFF2666B);  // Serious delay / disruption
  static const Color scheduledGray = Color(0xFF9198AD); // Según horario

  // ── 13 Operator Brand Colors (Euskadi) ────────────────────────────────────
  static const Color opRenfe = Color(0xFFD0142B);
  static const Color opMetroBilbao = Color(0xFFE8590C);
  static const Color opEuskotren = Color(0xFF025DA9);
  static const Color opTranbia = Color(0xFF2FA650);
  static const Color opBizkaibus = Color(0xFF2E9E4F);
  static const Color opBilbobus = Color(0xFFD7143C);
  static const Color opDbus = Color(0xFF1D7FD1);
  static const Color opLurraldebus = Color(0xFF5E9424);
  static const Color opTuvisa = Color(0xFF12979F);
  static const Color opAlavabus = Color(0xFFB04A8E);
  static const Color opArtxanda = Color(0xFFDC0B0B);
  static const Color opLaUnion = Color(0xFF30609D);

  // ── Core Brand ────────────────────────────────────────────────────────────
  static const Color brandRed = Color(0xFFE3202B);
  static const Color brandNavy = Color(0xFF0F172A);

  // ── Backward-compatible Aliases ───────────────────────────────────────────
  static const Color metroRed = opMetroBilbao;
  static const Color metroRedDark = Color(0xFFB30014);
  static const Color metroRedLight = Color(0xFFFF4D5E);
  static const Color metroL2 = Color(0xFF1E293B);
  static const Color busGreen = opBizkaibus;
  static const Color bizkaibusGreen = opBizkaibus;
  static const Color busGreenDark = Color(0xFF005E2B);
  static const Color busGreenLight = Color(0xFF10B981);
  static const Color bilbobusRed = opBilbobus;
  static const Color brandBlue = Color(0xFF0052CC);

  static const Color background = darkBackground;
  static const Color surface = darkSurface;
  static const Color surfaceCard = darkSurface;
  static const Color surfaceSecondary = darkSurfaceElevated;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextSecondary;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color borderLight = darkBorder;
  static const Color borderFocus = darkBorderStrong;

  static const Color livePulse = realtimeGreen;
  static const Color warning = delayedAmber;
  static const Color error = disruptedRed;
  static const Color success = realtimeGreen;

  static const Color primary = opMetroBilbao;
  static const Color primaryLight = metroRedLight;
  static const Color primaryDark = metroRedDark;
  static const Color secondary = opBizkaibus;
  static const Color secondaryLight = busGreenLight;
  static const Color secondaryDark = busGreenDark;
  static const Color onSecondary = onPrimary;
  static const Color onSurface = darkTextPrimary;
  static const Color onSurfaceVariant = darkTextSecondary;
  static const Color surfaceVariant = darkSurfaceElevated;
  static const Color outline = darkBorderStrong;
  static const Color outlineVariant = darkBorder;
  static const Color darkAccent = metroL2;
  static const Color metroL1 = opMetroBilbao;
  static const Color bizkaibus = opBizkaibus;
  static const Color renfe = opRenfe;
}
