import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/utils/geo.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/stop/stop_departures_screen.dart';
import 'package:bizkaia_transit/presentation/widgets/departure_row.dart';

/// Full-screen map tab: centres on the user, shows every stop around them
/// (all operators) and reloads stops for whatever area the camera rests on.
/// Tapping a stop opens a sheet with its next departures.
class TransitMapScreen extends ConsumerStatefulWidget {
  const TransitMapScreen({super.key});

  @override
  ConsumerState<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends ConsumerState<TransitMapScreen> {
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const _walkingZoom = 15.5;
  static const _initialRadiusKm = 0.6;
  static const _sourceId = 'stops';
  static const _layerId = 'stops-circles';

  MapLibreMapController? _controller;
  bool _styleReady = false;
  Timer? _debounce;
  Map<String, Stop> _visibleStops = const {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  // ── Map lifecycle ────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.addGeoJsonSource(_sourceId, _featureCollection(const []));
    await controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          12,
          4,
          16,
          8,
        ],
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    _styleReady = true;

    final here = await ref.read(resolvedUserLocationProvider.future);
    final around = await ref.read(
      stopsAroundProvider(
        (lat: here.latitude, lon: here.longitude, radiusKm: _initialRadiusKm),
      ).future,
    );
    await _showStops(around);
  }

  /// Debounced reload of the stops inside the resting viewport.
  void _onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final controller = _controller;
      if (controller == null || !_styleReady || !mounted) return;
      final bounds = await controller.getVisibleRegion();
      final stops = await ref.read(transitRepositoryProvider).getStopsInBounds(
            minLat: bounds.southwest.latitude,
            maxLat: bounds.northeast.latitude,
            minLon: bounds.southwest.longitude,
            maxLon: bounds.northeast.longitude,
          );
      if (mounted) await _showStops(stops);
    });
  }

  Future<void> _showStops(List<Stop> stops) async {
    _visibleStops = {for (final s in stops) s.id: s};
    await _controller?.setGeoJsonSource(_sourceId, _featureCollection(stops));
  }

  Map<String, dynamic> _featureCollection(List<Stop> stops) => {
        'type': 'FeatureCollection',
        'features': [
          for (final s in stops)
            if (s.latitude != null && s.longitude != null)
              {
                'type': 'Feature',
                'id': s.id,
                'properties': {
                  'stopId': s.id,
                  'color': _hex(TransitOperator.fromId(s.operatorId).colorHex),
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [s.longitude, s.latitude],
                },
              },
        ],
      };

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _onFeatureTapped(
    math.Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _layerId) return;
    // Feature ids are not guaranteed to round-trip on every platform, so fall
    // back to the stop closest to the tap.
    final stop = _visibleStops[id] ??
        (_visibleStops.values.toList()
              ..sort(
                (a, b) => haversineKm(
                  coordinates.latitude,
                  coordinates.longitude,
                  a.latitude!,
                  a.longitude!,
                ).compareTo(
                  haversineKm(
                    coordinates.latitude,
                    coordinates.longitude,
                    b.latitude!,
                    b.longitude!,
                  ),
                ),
              ))
            .firstOrNull;
    if (stop == null) return;
    HapticFeedback.selectionClick();
    _StopSheet.show(context, stop);
  }

  Future<void> _recenter(UserLocation here) async {
    HapticFeedback.selectionClick();
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(here.latitude, here.longitude),
        _walkingZoom,
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(resolvedUserLocationProvider);
    // A real GPS fix (not the Moyúa fallback) is the only case where the
    // blue "you are here" dot is truthful.
    final hasRealFix = ref.watch(userLocationProvider) != null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: location.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (here) => Stack(
          children: [
            MapLibreMap(
              styleString: _styleUrl,
              initialCameraPosition: CameraPosition(
                target: LatLng(here.latitude, here.longitude),
                zoom: _walkingZoom,
              ),
              myLocationEnabled: hasRealFix,
              compassEnabled: false,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onCameraIdle: _onCameraIdle,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: const math.Point(12, 100),
            ),
            if (!hasRealFix)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 16,
                right: 16,
                child: const _InfoPill(
                  text: 'Sin ubicación: mostrando el centro de Bilbao',
                ),
              ),
            Positioned(
              right: 16,
              bottom: 108,
              child: FloatingActionButton.small(
                heroTag: 'map_recenter',
                tooltip: 'Centrar en mi posición',
                backgroundColor: AppColors.darkSurfaceElevated,
                foregroundColor: AppColors.darkTextPrimary,
                onPressed: () => _recenter(here),
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Draggable sheet with a stop's next departures and one-tap origin /
/// destination selection.
class _StopSheet extends ConsumerWidget {
  const _StopSheet({required this.stop, required this.scrollController});

  final Stop stop;
  final ScrollController scrollController;

  static Future<void> show(BuildContext context, Stop stop) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the shell, so the tab bar and centre FAB don't cover the list.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) =>
            _StopSheet(stop: stop, scrollController: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = TransitOperator.fromId(stop.operatorId);
    final opColor = Color(operator.colorHex);
    final departures = ref.watch(departuresForStopProvider(stop));
    final destinationAllowed = canBeDestination(ref, stop);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.darkBorderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: opColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        operator.name,
                        style: TextStyle(
                          color: opColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.name,
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: opColor,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            selectStopAsOrigin(ref, stop);
                            Navigator.of(context).pop();
                            context.go('/');
                          },
                          child: const Text('Salir de aquí'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            foregroundColor: AppColors.darkTextPrimary,
                            side: const BorderSide(
                              color: AppColors.darkBorderStrong,
                            ),
                          ),
                          onPressed: destinationAllowed
                              ? () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(
                                        selectedDestinationStopProvider
                                            .notifier,
                                      )
                                      .state = stop;
                                  Navigator.of(context).pop();
                                  context.go('/');
                                }
                              : null,
                          child: const Text('Ir hasta aquí'),
                        ),
                      ),
                    ],
                  ),
                  if (!destinationAllowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Para usarla como destino, elige antes un origen de '
                        '${operator.name}.',
                        style: const TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Próximas salidas',
                        style: TextStyle(
                          color: AppColors.darkTextSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          StopDeparturesScreen.open(context, stop);
                        },
                        child: const Text('Ver todas'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ...departures.when(
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, __) => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No se han podido cargar las salidas.',
                    style: TextStyle(color: AppColors.darkTextSecondary),
                  ),
                ),
              ),
            ],
            data: (list) => list.isEmpty
                ? const [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Sin salidas programadas.',
                          style: TextStyle(color: AppColors.darkTextSecondary),
                        ),
                      ),
                    ),
                  ]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverFixedExtentList.builder(
                        itemExtent: DepartureRow.extentOf(context),
                        itemCount: math.min(list.length, 6),
                        itemBuilder: (_, i) => DepartureRow(
                          departure: list[i],
                          operator: operator,
                        ),
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
