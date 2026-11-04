import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// How the glass treats what is behind it.
enum GlassKind {
  /// Blurred, saturated backdrop with a dark tint: bars, sheets, buttons.
  regular,

  /// Over the map. On Android maplibre renders into a Flutter texture, so the
  /// blur works; on the web the map is a DOM node a backdrop can't sample,
  /// so there it fakes the material with a denser tint.
  overMap,

  /// Thin, mostly transparent glass for rich backgrounds (onboarding).
  clear,
}

/// Liquid-glass material (iOS 26 style) for the navigation layer only —
/// content cards stay solid. Continuous (superellipse) corners, a gradient
/// rim, a top specular highlight and a two-part shadow.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.kind = GlassKind.regular,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.shadow = true,
    this.blur = false,
  });

  final Widget child;
  final GlassKind kind;

  /// Real backdrop blur. Off by default: over the aurora (a smooth gradient)
  /// a blur is invisible but costs a full backdrop pass every frame anything
  /// behind repaints. Turn it on only where content moves underneath — the
  /// tab bar, sheets, pinned bars, controls over the map.
  final bool blur;

  /// Corner radius; use a large value (e.g. 999) for capsules.
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Optional colour wash (e.g. a tinted primary button).
  final Color? tint;
  final bool shadow;

  static const _baseTint = Color(0xFF1D1D20);

  static const _shadows = [
    BoxShadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final shape = continuousShape(
      borderRadius: BorderRadius.circular(radius),
    );
    // The web has no raster cache: every scrolled frame repaints each
    // backdrop blur and each large shadow. Measured on a throttled phone
    // profile, those two were half of all dropped frames — so on the web
    // glass never blurs and keeps only the contact shadow. Where content
    // moves underneath (this.blur requested), a denser tint keeps it legible.
    final blur = this.blur && !kIsWeb;
    final tintAlpha = switch (kind) {
      GlassKind.regular => blur ? 0.58 : (this.blur ? 0.92 : 0.30),
      GlassKind.overMap => blur ? 0.66 : 0.88,
      GlassKind.clear => 0.22,
    };
    // Web: no shadow at all (even a 2 px one is a blur pass per frame);
    // the rim draws the edge.
    final shadows = shadow && !kIsWeb ? _shadows : null;
    // Tinted glass is the screen's primary action: mostly the tint colour,
    // still a touch translucent so the rim and sheen read as glass.
    final fill = tint != null
        ? Color.alphaBlend(tint!.withValues(alpha: 0.86), _baseTint)
            .withValues(alpha: 0.9)
        : _baseTint.withValues(alpha: tintAlpha);

    // Fill and sheen are painted with the shape itself, so the frosted
    // (no-blur) variant needs no clip layer at all.
    final sheen =
        Colors.white.withValues(alpha: kind == GlassKind.clear ? 0.10 : 0.08);
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: fill,
        // With blur, the shadow goes outside the clip (below), never under
        // the translucent fill.
        shadows: blur ? null : shadows,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheen, sheen.withValues(alpha: 0)],
            stops: const [0, 0.38],
          ),
        ),
        position: DecorationPosition.foreground,
        child: CustomPaint(
          foregroundPainter: _RimPainter(shape),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (!blur) return body;

    // Native only (see above): blur + saturation behind the shape.
    final sigma = kind == GlassKind.clear ? 6.0 : 18.0;
    final blurFilter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.mirror,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: RepaintBoundary(
        child: ContinuousClip(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.compose(
              outer: blurFilter,
              inner: const ColorFilter.matrix(_saturate170),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Saturation ×1.7 (Rec. 709 luma) — the "vibrancy" that makes colour
/// behind glass glow.
const List<double> _saturate170 = [
  1.5512, -0.5006, -0.0505, 0, 0, //
  -0.1488, 1.1994, -0.0505, 0, 0, //
  -0.1488, -0.5006, 1.6495, 0, 0, //
  0, 0, 0, 1, 0, //
];

class _RimPainter extends CustomPainter {
  _RimPainter(this.shape);

  final ShapeBorder shape;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.16),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    final shape = this.shape;
    if (shape is RoundedRectangleBorder) {
      canvas.drawRRect(
        shape.borderRadius.resolve(TextDirection.ltr).toRRect(rect),
        paint,
      );
    } else {
      canvas.drawPath(shape.getOuterPath(rect), paint);
    }
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.shape != shape;
}

/// Tappable glass: springs down to 0.96 while pressed and back with a
/// little bounce, with a light haptic. No ink splash.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.kind = GlassKind.regular,
    this.radius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.tint,
    this.semanticLabel,
    this.blur = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool blur;
  final GlassKind kind;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final String? semanticLabel;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onPressed == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final motion = _down ? Motion.snappy : Motion.bouncy;
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _down && !reduced ? Motion.pressedScale : 1,
          duration: reduced ? Duration.zero : motion.duration,
          curve: motion.curve,
          child: GlassSurface(
            kind: widget.kind,
            radius: widget.radius,
            padding: widget.padding,
            tint: widget.onPressed == null ? null : widget.tint,
            blur: widget.blur,
            // Disabled: dim the content, not the glass (a fade breaks blur).
            child: widget.onPressed == null
                ? Opacity(opacity: 0.38, child: widget.child)
                : widget.child,
          ),
        ),
      ),
    );
  }
}
