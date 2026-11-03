import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/utils/geo.dart';
import 'package:bizkaia_transit/data/live/live_vehicles.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';

/// What the "En directo" chip shows.
enum LiveStatus { connecting, live, unavailable }

@immutable
class LiveLayerState {
  const LiveLayerState({
    this.status = LiveStatus.connecting,
    this.count = 0,
    this.visible = true,
    this.snapshot,
  });

  final LiveStatus status;
  final int count;
  final bool visible;
  final LiveVehiclesSnapshot? snapshot;

  LiveLayerState copyWith({
    LiveStatus? status,
    int? count,
    bool? visible,
    LiveVehiclesSnapshot? snapshot,
  }) =>
      LiveLayerState(
        status: status ?? this.status,
        count: count ?? this.count,
        visible: visible ?? this.visible,
        snapshot: snapshot ?? this.snapshot,
      );
}

/// Live vehicles on the map: polls the vehicle proxy every 20 s while the map
/// is on screen, draws one GeoJSON layer (no Flutter widget per vehicle) and
/// glides each vehicle to its new position instead of jumping.
///
/// GPS vehicles (Bizkaibus) are solid dots with a white rim; trains placed by
/// station (Metro, Renfe) are rings in the line colour — they read as
/// "approximate", which is what they are.
class LiveVehiclesController {
  LiveVehiclesController({LiveVehiclesService? service, required this.reduceMotion})
      : _service = service ?? LiveVehiclesService();

  static const sourceId = 'live-vehicles';
  static const layerId = 'live-vehicles-dots';
  static const labelLayerId = 'live-vehicles-labels';
  static const _pollEvery = Duration(seconds: 20);

  /// Proxy data older than this is not live any more: hide it.
  static const _staleAfter = Duration(minutes: 3);

  /// Jumps longer than this (feed glitches, a train re-detected far away)
  /// are not animated across the map.
  static const _maxGlideKm = 3.0;

  final LiveVehiclesService _service;
  final bool Function() reduceMotion;
  final ValueNotifier<LiveLayerState> state =
      ValueNotifier(const LiveLayerState());

  MapLibreMapController? _map;
  Timer? _poll;
  Timer? _glide;
  bool _active = false;
  bool _fetching = false;
  Map<String, LiveVehicle> _vehicles = const {};
  Map<String, LatLng> _shown = const {};

  /// Adds the source and layers. Call once the style has loaded.
  Future<void> attach(MapLibreMapController map) async {
    _map = map;
    await map.addGeoJsonSource(sourceId, _collection(const {}, const {}));
    await map.addCircleLayer(
      sourceId,
      layerId,
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'fill'],
        circleStrokeColor: [Expressions.get, 'stroke'],
        circleStrokeWidth: [
          Expressions.caseExpression,
          [Expressions.equal, [Expressions.get, 'kind'], 'gps'],
          2,
          3,
        ],
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          11,
          3.5,
          14,
          6,
          16,
          8,
          18,
          10,
        ],
      ),
    );
    await map.addSymbolLayer(
      sourceId,
      labelLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'line'],
        textFont: ['Noto Sans Regular'],
        textSize: 11,
        textColor: '#FFFFFF',
        textHaloColor: '#06080C',
        textHaloWidth: 1.6,
        textOffset: [
          Expressions.literal,
          [0, 1.25],
        ],
        textAnchor: 'top',
        textOptional: true,
      ),
      minzoom: 13,
      enableInteraction: false,
    );
    if (_active) _refresh();
  }

  /// Poll only while the map is on screen (tab visible, app in foreground).
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    if (active) {
      _refresh();
      _poll = Timer.periodic(_pollEvery, (_) => _refresh());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void toggleVisible() {
    final visible = !state.value.visible;
    state.value = state.value.copyWith(visible: visible);
    _glide?.cancel();
    _send(1, _shown, visible ? _vehicles : const {});
  }

  /// The vehicle behind a tap: by feature id, else the closest drawn one.
  LiveVehicle? vehicleAt(String featureId, LatLng tap) {
    final byId = _vehicles[featureId];
    if (byId != null) return byId;
    LiveVehicle? best;
    var bestKm = double.infinity;
    for (final v in _vehicles.values) {
      final p = _shown[v.id] ?? LatLng(v.latitude, v.longitude);
      final km = haversineKm(tap.latitude, tap.longitude, p.latitude, p.longitude);
      if (km < bestKm) {
        bestKm = km;
        best = v;
      }
    }
    return best;
  }

  Future<void> _refresh() async {
    if (_fetching || _map == null) return;
    _fetching = true;
    try {
      final snap = await _service.fetch();
      final fresh = {
        for (final v in snap.vehicles)
          if (DateTime.now().difference(v.reportedAt) < _staleAfter) v.id: v,
      };
      state.value = state.value.copyWith(
        status: fresh.isEmpty ? LiveStatus.unavailable : LiveStatus.live,
        count: fresh.length,
        snapshot: snap,
      );
      _apply(fresh);
    } catch (_) {
      // Keep what is drawn only while it is still fresh; then clear it.
      final last = state.value.snapshot;
      final stale = last == null ||
          DateTime.now().difference(last.fetchedAt) > _staleAfter;
      if (stale) {
        state.value = state.value.copyWith(status: LiveStatus.unavailable, count: 0);
        _apply(const {});
      }
    } finally {
      _fetching = false;
    }
  }

  void _apply(Map<String, LiveVehicle> next) {
    final from = _shown;
    _vehicles = next;
    _glide?.cancel();
    if (!state.value.visible) return;
    if (reduceMotion() || from.isEmpty) {
      _send(1, from, next);
      return;
    }
    const steps = 12;
    var step = 0;
    _glide = Timer.periodic(const Duration(milliseconds: 90), (t) {
      step++;
      _send(Curves.easeInOutCubic.transform(step / steps), from, next);
      if (step >= steps) t.cancel();
    });
  }

  void _send(double f, Map<String, LatLng> from, Map<String, LiveVehicle> to) {
    final positions = <String, LatLng>{};
    for (final v in to.values) {
      final end = LatLng(v.latitude, v.longitude);
      final start = from[v.id];
      final glide = start != null &&
          haversineKm(start.latitude, start.longitude, end.latitude, end.longitude) <
              _maxGlideKm;
      positions[v.id] = glide
          ? LatLng(
              start.latitude + (end.latitude - start.latitude) * f,
              start.longitude + (end.longitude - start.longitude) * f,
            )
          : end;
    }
    if (f >= 1) _shown = positions;
    _map?.setGeoJsonSource(sourceId, _collection(to, positions));
  }

  Map<String, dynamic> _collection(
    Map<String, LiveVehicle> vehicles,
    Map<String, LatLng> positions,
  ) =>
      {
        'type': 'FeatureCollection',
        'features': [
          for (final v in vehicles.values)
            {
              'type': 'Feature',
              'id': v.id,
              'properties': {
                'line': v.line,
                'kind': v.kind.name,
                'fill': v.kind == LivePositionKind.gps ? v.colorHex : '#06080C',
                'stroke': v.kind == LivePositionKind.gps ? '#FFFFFF' : v.colorHex,
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [
                  positions[v.id]?.longitude ?? v.longitude,
                  positions[v.id]?.latitude ?? v.latitude,
                ],
              },
            },
        ],
      };

  void dispose() {
    _poll?.cancel();
    _glide?.cancel();
    state.dispose();
  }
}

/// Glass chip over the map: "En directo · 297 vehículos", with an eye button
/// to hide them; tapping the text explains GPS vs. station positions.
class LiveVehiclesChip extends StatelessWidget {
  const LiveVehiclesChip({super.key, required this.state, required this.onToggle});

  final ValueListenable<LiveLayerState> state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return ValueListenableBuilder<LiveLayerState>(
      valueListenable: state,
      builder: (context, s, _) {
        final (label, dot) = switch (s.status) {
          LiveStatus.connecting => ('Conectando con el directo…', AppColors.darkTextTertiary),
          LiveStatus.unavailable => ('Sin datos en directo ahora', AppColors.darkTextTertiary),
          LiveStatus.live => (
              s.visible ? 'En directo · ${s.count} vehículos' : 'Vehículos ocultos',
              s.visible ? AppColors.realtimeGreen : AppColors.darkTextTertiary,
            ),
        };
        return GlassSurface(
          blur: true,
          kind: GlassKind.overMap,
          radius: 999,
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  label: '$label. Qué significa',
                  onTap: () => _LiveInfoSheet.show(context, s.snapshot),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _LiveInfoSheet.show(context, s.snapshot),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium!.copyWith(
                              color: AppColors.darkTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTypography.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.darkTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: s.visible ? 'Ocultar vehículos' : 'Mostrar vehículos',
                onPressed: s.status == LiveStatus.live ? onToggle : null,
                icon: Icon(
                  s.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  size: 18,
                ),
                color: AppColors.darkTextSecondary,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the live dots mean, and where the data comes from.
class _LiveInfoSheet extends StatelessWidget {
  const _LiveInfoSheet({this.snapshot});

  final LiveVehiclesSnapshot? snapshot;

  static Future<void> show(BuildContext context, LiveVehiclesSnapshot? snapshot) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LiveInfoSheet(snapshot: snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final failed = snapshot?.failedFeeds ?? const <String>[];
    Widget row(Widget marker, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 28, child: Center(child: marker)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall!.copyWith(color: AppColors.darkTextPrimary)),
                    const SizedBox(height: 2),
                    Text(body, style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: GlassSurface(
          blur: true,
          kind: GlassKind.overMap,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehículos en directo', style: t.headlineSmall!.copyWith(color: AppColors.darkTextPrimary)),
              const SizedBox(height: 16),
              row(
                const _Marker(gps: true, color: Color(0xFF9CCD64)),
                'GPS en directo · Bizkaibus',
                'Posición real del autobús, actualizada cada minuto aproximadamente.',
              ),
              row(
                const _Marker(gps: false, color: Color(0xFFFF6505)),
                'Por estación · Metro Bilbao y Renfe',
                'El operador sitúa cada tren en una estación de su recorrido '
                    '(en la que está o a la que se dirige), no en su posición '
                    'exacta. No es GPS.',
              ),
              row(
                const Icon(Icons.do_not_disturb_on_outlined, size: 18, color: AppColors.darkTextTertiary),
                'Sin posiciones en directo',
                'Bilbobus y Euskotren no publican ahora posiciones de sus vehículos. '
                    'Sus salidas se muestran según horario.',
              ),
              if (failed.isNotEmpty)
                row(
                  const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.delayedAmber),
                  'Sin conexión con: ${failed.join(', ')}',
                  'Ese operador no ha respondido en la última consulta.',
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  (snapshot?.attribution.isNotEmpty ?? false)
                      ? snapshot!.attribution
                      : 'Datos en directo: CTB · Diputación Foral de Bizkaia · Renfe (CC BY 4.0)',
                  style: t.labelMedium!.copyWith(color: AppColors.darkTextTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.gps, required this.color});

  final bool gps;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gps ? color : AppColors.darkBackground,
        border: Border.all(color: gps ? Colors.white : color, width: gps ? 2 : 3),
      ),
    );
  }
}

/// Sheet for a tapped vehicle: line, destination, where it is and how old
/// that information is — with the honest caveat for station-based trains.
class VehicleSheet extends StatelessWidget {
  const VehicleSheet({super.key, required this.vehicle, this.attribution});

  final LiveVehicle vehicle;
  final String? attribution;

  static Future<void> show(BuildContext context, LiveVehicle vehicle, {String? attribution}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleSheet(vehicle: vehicle, attribution: attribution),
    );
  }

  static Color _color(String hex) =>
      Color(int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16) ?? 0xFF0A84FF);

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final v = vehicle;
    final ageS = DateTime.now().difference(v.reportedAt).inSeconds.clamp(0, 9999);
    final age = ageS < 60 ? 'hace $ageS s' : 'hace ${ageS ~/ 60} min';
    final gps = v.kind == LivePositionKind.gps;
    final where = v.stopName == null
        ? null
        : gps
            ? 'Cerca de ${v.stopName}'
            // GTFS-RT VehicleStopStatus: the stop is the one the train is at,
            // arriving at, or (IN_TRANSIT_TO) heading to.
            : switch (v.status) {
                'incoming' => 'Llegando a ${v.stopName}',
                'stopped' => 'En ${v.stopName}',
                _ => 'Camino de ${v.stopName}',
              };

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: GlassSurface(
          blur: true,
          kind: GlassKind.overMap,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LineBadge(label: v.line, color: _color(v.colorHex), large: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.headsign != null ? 'Hacia ${v.headsign}' : v.operatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleLarge!.copyWith(color: AppColors.darkTextPrimary),
                        ),
                        Text(
                          v.operatorName,
                          style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (where != null)
                Text(where, style: t.titleMedium!.copyWith(color: AppColors.darkTextPrimary)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gps ? AppColors.realtimeGreen : AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    gps ? 'GPS en directo · $age' : 'Posición por estación · $age',
                    style: AppTypography.time.copyWith(
                      color: gps ? AppColors.realtimeGreen : AppColors.darkTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!gps) ...[
                const SizedBox(height: 10),
                Text(
                  'No es GPS: el operador sitúa el tren en una estación de su '
                  'recorrido, no en su posición exacta.',
                  style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                attribution ?? 'Datos en directo: CTB · Diputación Foral de Bizkaia · Renfe (CC BY 4.0)',
                style: t.labelMedium!.copyWith(color: AppColors.darkTextTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
