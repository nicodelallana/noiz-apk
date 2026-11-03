import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Interactive open vector map view powered by MapLibre GL.
///
/// Uses open, keyless vector map tiles (OpenFreeMap / MapLibre) without Google Maps.
/// Automatically animates camera position when the active station coordinates change.
///
/// It lives in scrolling content, so its overlays are solid (no glass).
class TransitMapView extends StatefulWidget {
  const TransitMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.stationName = 'Estación',
    this.height = 210,
    this.primaryColor = const Color(0xFFE2001A),
    this.isBusMode = false,
  });

  final double latitude;
  final double longitude;
  final String stationName;
  final double height;
  final Color primaryColor;
  final bool isBusMode;

  @override
  State<TransitMapView> createState() => _TransitMapViewState();
}

class _TransitMapViewState extends State<TransitMapView> {
  MapLibreMapController? _mapController;
  bool _reduced = false;

  /// Same dark OpenFreeMap basemap as the map tab.
  static const String _mapStyle = 'https://tiles.openfreemap.org/styles/dark';

  static const double _radius = 24;

  /// Solid overlay fill: the content surface at 90 %.
  static const Color _overlayFill = Color(0xE614161C);

  @override
  void didUpdateWidget(covariant TransitMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _animateToCurrentStation();
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _animateToCurrentStation();
  }

  void _animateToCurrentStation() {
    final update = CameraUpdate.newLatLngZoom(
      LatLng(widget.latitude, widget.longitude),
      14.8,
    );
    if (_reduced) {
      _mapController?.moveCamera(update);
    } else {
      _mapController?.animateCamera(update);
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduced = Motion.reduced(context);

    return ContinuousClip(
      borderRadius: BorderRadius.circular(_radius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            // ── Live MapLibre Vector Map ────────────────────────────────────
            MapLibreMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.latitude, widget.longitude),
                zoom: 14.5,
              ),
              styleString: _mapStyle,
              onMapCreated: _onMapCreated,
              compassEnabled: false,
              myLocationEnabled: false,
              // Bottom-left, away from the recenter button.
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: const math.Point(8, 8),
            ),

            // ── Station marker: the map tab's selected-stop dot + its name ──
            IgnorePointer(
              child: Stack(
                children: [
                  Center(child: _StationDot(color: widget.primaryColor)),
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -30),
                      child: _StationLabel(name: widget.stationName),
                    ),
                  ),
                ],
              ),
            ),

            // ── Hairline rim, like the solid content cards ─────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: continuousShape(
                      borderRadius: BorderRadius.circular(_radius),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                ),
              ),
            ),

            // ── Recenter Button ─────────────────────────────────────────────
            Positioned(
              bottom: 10,
              right: 10,
              child: Tooltip(
                message: 'Centrar en la parada',
                child: Material(
                  color: _overlayFill,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppColors.darkBorderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _animateToCurrentStation,
                    child: const SizedBox.square(
                      dimension: 36,
                      child: Icon(
                        Icons.near_me_rounded,
                        size: 17,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Operator-coloured dot with a white rim and a soft halo — the same mark
/// the map tab uses for the selected stop.
class _StationDot extends StatelessWidget {
  const _StationDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _StationLabel extends StatelessWidget {
  const _StationLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: _TransitMapViewState._overlayFill,
          shape: continuousShape(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.darkBorderStrong),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme().labelMedium!.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
