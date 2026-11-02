import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// The backdrop glass needs: a near-black canvas with three soft colour
/// glows (teal, indigo and the active operator's colour) drifting over ~40 s.
/// Radial gradients rather than blur filters, and the drift ticks at 12 fps:
/// every repaint also re-blurs the glass above it, so 60 fps would only
/// burn battery for movement nobody can see.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.accent,
    this.animate = true,
    this.child,
  });

  /// Third glow; usually the selected operator's colour.
  final Color? accent;

  /// Drift slowly; off for pushed screens and when hidden behind the map.
  final bool animate;
  final Widget? child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> {
  static const _period = Duration(seconds: 40);
  static const _tick = Duration(milliseconds: 83);

  final _phase = ValueNotifier<double>(0.2);
  final _clock = Stopwatch();
  Timer? _timer;

  void _sync() {
    final run = widget.animate && !Motion.reduced(context);
    if (run && _timer == null) {
      _clock.start();
      _timer = Timer.periodic(_tick, (_) {
        _phase.value = 0.2 +
            _clock.elapsedMilliseconds / _period.inMilliseconds % 1;
      });
    } else if (!run && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AuroraBackground old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? AppColors.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: accent),
            duration: Motion.smooth.duration,
            curve: Motion.smooth.curve,
            builder: (context, color, _) => CustomPaint(
              painter: _AuroraPainter(_phase, color ?? accent),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.phase, this.accent) : super(repaint: phase);

  final ValueListenable<double> phase;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.darkBackground,
    );
    final t = phase.value * 2 * math.pi;
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

    glow(
      Offset(w * (0.15 + 0.10 * math.sin(t)), h * (0.08 + 0.05 * math.cos(t))),
      r * 0.75,
      const Color(0xFF1FB5A8),
      0.26,
    );
    glow(
      Offset(w * (0.95 + 0.08 * math.cos(t * 1.3)), h * (0.30 + 0.06 * math.sin(t))),
      r * 0.70,
      const Color(0xFF4A4DE6),
      0.30,
    );
    glow(
      Offset(w * (0.40 + 0.12 * math.sin(t * 0.7 + 1)), h * (0.78 + 0.05 * math.cos(t * 1.1))),
      r * 0.80,
      accent,
      0.20,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.accent != accent;
}
