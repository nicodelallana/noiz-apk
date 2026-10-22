import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Accessible, performance-isolated pulse animation for imminent transit arrivals.
///
/// Wrapped in a [RepaintBoundary] to isolate rendering ticks from parent list views.
/// Respects accessibility reduce-motion settings via [MediaQuery.disableAnimationsOf].
class ArrivalPulseIndicator extends StatelessWidget {
  const ArrivalPulseIndicator({
    super.key,
    this.size = 28.0,
    this.fallbackColor = const Color(0xFF10B981),
  });

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: size * 0.45,
        height: size * 0.45,
        decoration: BoxDecoration(
          color: fallbackColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/lottie/arrival_pulse.json',
          fit: BoxFit.contain,
          frameRate: FrameRate.composition,
        ),
      ),
    );
  }
}
