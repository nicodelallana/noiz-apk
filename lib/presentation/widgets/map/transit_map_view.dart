import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Interactive open vector map view powered by MapLibre GL.
///
/// Uses open, keyless vector map tiles (OpenFreeMap / MapLibre) without Google Maps.
/// Automatically animates camera position when the active station coordinates change.
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

  static const String _mapStyle =
      'https://tiles.openfreemap.org/styles/liberty';

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
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.latitude, widget.longitude),
        14.8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
              attributionButtonMargins: const math.Point(8, 8),
            ),

            // ── Top Gradient Overlay for readability ───────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Central Station Pin with Subtle Pulse ──────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.stationName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.location_on,
                    size: 36,
                    color: widget.primaryColor,
                  ),
                ],
              ),
            ),

            // ── Mode Indicator Tag ──────────────────────────────────────────
            Positioned(
              top: 12,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isBusMode
                          ? Icons.directions_bus_rounded
                          : Icons.subway_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isBusMode
                          ? 'Bizkaibus • En vivo'
                          : 'Metro Bilbao • En vivo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Recenter Button ─────────────────────────────────────────────
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map_fab',
                onPressed: _animateToCurrentStation,
                backgroundColor: Colors.white,
                foregroundColor: widget.primaryColor,
                elevation: 3,
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
