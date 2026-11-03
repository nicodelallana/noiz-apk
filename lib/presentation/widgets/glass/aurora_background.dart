import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// The backdrop glass needs: a near-black canvas with three soft colour
/// glows (teal, indigo and the active operator's colour).
///
/// Static on purpose. Any repaint here invalidates every blurred surface
/// above it, so a drifting aurora kept the GPU busy even with the app idle
/// (measured: ~29 % main-thread time at rest on a throttled phone profile).
/// It only animates when the operator — and so the third glow — changes.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.accent, this.child});

  /// Third glow; usually the selected operator's colour.
  final Color? accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = accent ?? AppColors.accent;
    final reduced = Motion.reduced(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: reduced ? Duration.zero : Motion.smooth.duration,
            curve: Motion.smooth.curve,
            builder: (context, color, _) => CustomPaint(
              painter: _AuroraPainter(color ?? target),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.darkBackground,
    );
    final w = size.width;
    final h = size.height;
    final r = math.max(w, h * 0.6);

    void glow(Offset c, double radius, Color color, double alpha) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.35),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    glow(Offset(w * 0.2, h * 0.1), r * 0.75, const Color(0xFF1FB5A8), 0.26);
    glow(Offset(w * 0.98, h * 0.33), r * 0.70, const Color(0xFF4A4DE6), 0.30);
    glow(Offset(w * 0.45, h * 0.80), r * 0.80, accent, 0.20);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.accent != accent;
}
