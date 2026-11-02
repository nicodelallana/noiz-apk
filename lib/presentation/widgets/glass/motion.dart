import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Apple-style springs expressed as SwiftUI's (response, dampingFraction),
/// turned into a [Curve] + [Duration] pair usable by any implicit animation.
@immutable
class SpringMotion {
  SpringMotion(double response, double damping)
      : this._(_simulationFor(response, damping));

  SpringMotion._(SpringSimulation sim)
      : duration = _settleTime(sim),
        curve = _SpringCurve(sim, _settleTime(sim));

  /// How long the spring takes to settle (within 0.1 %).
  final Duration duration;
  final Curve curve;

  static SpringSimulation _simulationFor(double response, double damping) {
    final stiffness = math.pow(2 * math.pi / response, 2).toDouble();
    return SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: stiffness,
        ratio: damping,
      ),
      0,
      1,
      0,
      tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
    );
  }

  static Duration _settleTime(SpringSimulation sim) {
    var t = 0.0;
    while (!sim.isDone(t) && t < 3) {
      t += 1 / 120;
    }
    return Duration(microseconds: (t * 1e6).round());
  }
}

class _SpringCurve extends Curve {
  const _SpringCurve(this._sim, this._duration);

  final SpringSimulation _sim;
  final Duration _duration;

  @override
  double transformInternal(double t) =>
      _sim.x(t * _duration.inMicroseconds / 1e6);
}

/// The few springs the app uses, named by intent.
abstract final class Motion {
  /// Default UI change (SwiftUI `.smooth`).
  static final smooth = SpringMotion(0.5, 1);

  /// Controls: tab indicator, chips, toggles.
  static final snappy = SpringMotion(0.35, 0.85);

  /// Press release, small pops.
  static final bouncy = SpringMotion(0.3, 0.6);

  /// Sheets and large panels.
  static final sheet = SpringMotion(0.45, 0.88);

  /// Pressed scale for tappable glass.
  static const double pressedScale = 0.96;

  /// Under "reduce motion" everything becomes a short crossfade.
  static const Duration reducedFade = Duration(milliseconds: 150);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
