import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Continuous (superellipse) corners on Android/iOS. On the web a
/// superellipse is a path drawn again on every frame (no raster cache there),
/// while a rounded rect is drawn analytically — at these radii the two are
/// indistinguishable, so the web gets the cheap one.
OutlinedBorder continuousShape({
  BorderRadiusGeometry borderRadius = BorderRadius.zero,
  BorderSide side = BorderSide.none,
}) {
  return kIsWeb
      ? RoundedRectangleBorder(borderRadius: borderRadius, side: side)
      : RoundedSuperellipseBorder(borderRadius: borderRadius, side: side);
}

/// Clip with [continuousShape] corners (rounded-rect clip on the web).
class ContinuousClip extends StatelessWidget {
  const ContinuousClip({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final BorderRadiusGeometry borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? ClipRRect(borderRadius: borderRadius, child: child)
        : ClipRSuperellipse(borderRadius: borderRadius, child: child);
  }
}
