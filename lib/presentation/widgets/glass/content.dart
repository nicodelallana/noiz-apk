import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Solid content surface (the content layer never uses glass): near-black
/// fill, hairline rim, a faint top highlight and continuous corners.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Optional coloured rim (e.g. the departure being followed).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final shape = continuousShape(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: accent?.withValues(alpha: 0.7) ?? AppColors.darkBorder,
        width: accent != null ? 1.5 : 1,
      ),
    );
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF21A1D24), Color(0xF214161C)],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          // InkSparkle compiles a shader on first tap (a visible hitch on web).
          splashFactory: InkRipple.splashFactory,
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Coloured line badge ("L1", "A3247") in the operator's colour.
class LineBadge extends StatelessWidget {
  const LineBadge({
    super.key,
    required this.label,
    required this.color,
    this.large = false,
  });

  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    // Light line colours (Bizkaibus green, Renfe C3 blue) need dark text.
    final onColor =
        color.computeLuminance() > 0.45 ? AppColors.darkBackground : Colors.white;
    return Container(
      constraints: BoxConstraints(minWidth: large ? 40 : 32),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 7,
        vertical: large ? 6 : 3,
      ),
      decoration: ShapeDecoration(
        color: color,
        shape: continuousShape(
          borderRadius: BorderRadius.circular(large ? 10 : 7),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: onColor,
          fontWeight: FontWeight.w700,
          fontSize: large ? 15 : 12,
          letterSpacing: -0.2,
          height: 1.15,
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}

/// Section title in the iOS grouped-list style ("Cerca de ti", "Toda la red").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 10),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleLarge!.copyWith(color: AppColors.darkTextPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// "En directo" (pulsing green dot) or "Según horario" (plain grey text).
/// Never colour alone: the words are always there.
class DepartureStatus extends StatelessWidget {
  const DepartureStatus({
    super.key,
    required this.isRealtime,
    this.delayMinutes = 0,
  });

  final bool isRealtime;
  final int delayMinutes;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.time.copyWith(fontSize: 13);
    if (delayMinutes > 0) {
      return Text(
        '+$delayMinutes min',
        style: style.copyWith(
          color: AppColors.delayedAmber,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (!isRealtime) {
      return Text(
        'Según horario',
        style: style.copyWith(color: AppColors.darkTextSecondary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A looping pulse keeps the web repainting the whole scene every
        // frame (no raster cache there): measured ~40 % CPU at rest. The web
        // gets a still dot; native pulses inside its own repaint boundary.
        if (kIsWeb) const _StillLiveDot() else const RepaintBoundary(child: _LiveDot()),
        const SizedBox(width: 6),
        Text(
          'En directo',
          style: style.copyWith(
            color: AppColors.realtimeGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StillLiveDot extends StatelessWidget {
  const _StillLiveDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.realtimeGreen,
            boxShadow: [
              BoxShadow(
                color: AppColors.realtimeGreen.withValues(alpha: 0.55),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6 + 8 * v,
                height: 6 + 8 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.realtimeGreen.withValues(alpha: 0.45 * (1 - v)),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.realtimeGreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "5 h 28 min" / "45 min" for waits shown as text.
String formatWait(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Minutes countdown whose number rolls up when it changes (SwiftUI's
/// numeric text transition); 0 reads "Ya". From an hour on it shows the
/// [clockTime] instead ("05:42" beats "328 min"). Tabular figures.
class CountdownText extends StatelessWidget {
  const CountdownText({
    super.key,
    required this.minutes,
    this.clockTime,
    this.style = AppTypography.countdown,
    this.unitStyle,
    this.color = AppColors.darkTextPrimary,
  });

  final int minutes;

  /// Departure clock time, shown instead of minutes for waits ≥ 60 min.
  final String? clockTime;
  final TextStyle style;
  final TextStyle? unitStyle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final now = minutes <= 0;
    final asClock = minutes >= 60 && clockTime != null;
    final number = Text(
      now ? 'Ya' : (asClock ? clockTime! : '$minutes'),
      key: ValueKey(now ? -1 : (asClock ? clockTime : minutes)),
      style: style.copyWith(color: color),
    );
    return Semantics(
      label: now
          ? 'Sale ya'
          : (asClock ? 'Sale a las $clockTime' : 'Sale en $minutes minutos'),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ClipRect(
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerRight,
                children: [...previous, if (current != null) current],
              ),
              transitionBuilder: (child, animation) {
                final incoming = child.key == number.key;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, incoming ? 0.5 : -0.5),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: number,
            ),
          ),
          if (!now && !asClock) ...[
            const SizedBox(width: 4),
            Text(
              'min',
              style: unitStyle ??
                  AppTypography.textTheme().titleMedium!.copyWith(
                        color: AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
            ),
          ],
        ],
      ),
    );
  }
}
