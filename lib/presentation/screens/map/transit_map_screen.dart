import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/services/location_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/utils/geo.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/stop/stop_departures_screen.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// Full-screen map tab: centres on the user, shows every stop around them
/// (all operators) and reloads stops for whatever area the camera rests on.
/// Tapping a stop opens a sheet with its next departures.
class TransitMapScreen extends ConsumerStatefulWidget {
  const TransitMapScreen({super.key});

  @override
  ConsumerState<TransitMapScreen> createState() => _TransitMapScreenState();
}

class _TransitMapScreenState extends ConsumerState<TransitMapScreen> {
  /// OpenFreeMap's dark basemap: near-black like the app canvas, so the
  /// operator-coloured stops are what stands out.
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/dark';
  static const _walkingZoom = 15.5;
  static const _initialRadiusKm = 0.6;
  static const _sourceId = 'stops';
  static const _layerId = 'stops-circles';
  static const _haloLayerId = 'stops-selected-halo';

  /// Clearance for the floating controls: the shell's tab bar ends at
  /// safe area + 74; while a departure is followed its banner sits above it.
  static const _controlsClearance = 90.0;
  static const _controlsClearanceFollowing = 162.0;

  /// Data-driven test for the stop whose sheet is open.
  static const _isSelected = [
    Expressions.equal,
    [Expressions.get, 'selected'],
    true,
  ];

  MapLibreMapController? _controller;
  bool _styleReady = false;
  Timer? _debounce;
  Map<String, Stop> _visibleStops = const {};
  String? _selectedStopId;

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
    // Soft glow under the selected stop; drawn first so the dots sit on top,
    // and not tappable so taps keep landing on the dots layer.
    await controller.addCircleLayer(
      _sourceId,
      _haloLayerId,
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleOpacity: 0.32,
        circleBlur: 0.45,
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          11,
          12,
          14,
          16,
          16,
          20,
          18,
          24,
        ],
      ),
      filter: _isSelected,
      enableInteraction: false,
    );
    // Operator-coloured dots with a dark rim; the selected one grows, takes
    // a white rim and draws above its neighbours.
    await controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          11,
          [Expressions.caseExpression, _isSelected, 6, 2.5],
          14,
          [Expressions.caseExpression, _isSelected, 8, 4],
          16,
          [Expressions.caseExpression, _isSelected, 10, 6],
          18,
          [Expressions.caseExpression, _isSelected, 12, 8],
        ],
        circleStrokeColor: [
          Expressions.caseExpression,
          _isSelected,
          '#FFFFFF',
          '#06080C',
        ],
        circleStrokeWidth: [Expressions.caseExpression, _isSelected, 3, 2],
        circleSortKey: [Expressions.caseExpression, _isSelected, 1, 0],
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

  /// Marks [stopId] as selected (or clears it) by re-sending the source with
  /// the `selected` flag the layers style on.
  Future<void> _setSelected(String? stopId) async {
    if (_selectedStopId == stopId) return;
    _selectedStopId = stopId;
    if (!_styleReady) return;
    await _showStops(_visibleStops.values.toList());
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
                  'selected': s.id == _selectedStopId,
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
    _openStop(stop);
  }

  Future<void> _openStop(Stop stop) async {
    unawaited(_setSelected(stop.id));
    await _StopSheet.show(context, stop);
    if (mounted) unawaited(_setSelected(null));
  }

  Future<void> _recenter(UserLocation here) async {
    // The glass button already gives the haptic tick.
    final update = CameraUpdate.newLatLngZoom(
      LatLng(here.latitude, here.longitude),
      _walkingZoom,
    );
    if (Motion.reduced(context)) {
      await _controller?.moveCamera(update);
    } else {
      await _controller?.animateCamera(update);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(resolvedUserLocationProvider);
    // A real GPS fix (not the Moyúa fallback) is the only case where the
    // blue "you are here" dot is truthful.
    final hasRealFix = ref.watch(userLocationProvider) != null;
    final following = ref.watch(activeLiveTripProvider) != null;
    final padding = MediaQuery.paddingOf(context);
    final controlsBottom = padding.bottom +
        (following ? _controlsClearanceFollowing : _controlsClearance);
    final reduced = Motion.reduced(context);
    final move = reduced ? Duration.zero : Motion.smooth.duration;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: location.when(
        loading: () => const Center(child: _Spinner()),
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
              // Native: bottom-left, level with the recenter button and clear
              // of the tab bar. The web ignores margins (see _MapAttribution).
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: math.Point(16, controlsBottom),
            ),
            if (!hasRealFix)
              Positioned(
                top: padding.top + 12,
                left: 16,
                right: 16,
                child: const Center(child: _NoFixPill()),
              ),
            if (kIsWeb)
              AnimatedPositioned(
                duration: move,
                curve: Motion.smooth.curve,
                left: 16,
                right: 84,
                bottom: controlsBottom,
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: _MapAttribution(),
                ),
              ),
            AnimatedPositioned(
              duration: move,
              curve: Motion.smooth.curve,
              right: 16,
              bottom: controlsBottom,
              child: _RecenterButton(
                located: hasRealFix,
                onPressed: () => _recenter(here),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.darkTextSecondary,
      ),
    );
  }
}

/// Glass capsule over the map while there's no GPS fix.
class _NoFixPill extends StatelessWidget {
  const _NoFixPill();

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return GlassSurface(
      kind: GlassKind.overMap,
      radius: 999,
      padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.delayedAmber,
              boxShadow: [
                BoxShadow(
                  color: AppColors.delayedAmber.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Sin ubicación: mostrando el centro de Bilbao',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.labelMedium!.copyWith(
                color: AppColors.darkTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round glass button that flies the camera back to the user.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.located, required this.onPressed});

  final bool located;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Centrar en mi posición',
      excludeFromSemantics: true,
      child: GlassButton(
        kind: GlassKind.overMap,
        padding: EdgeInsets.zero,
        semanticLabel: 'Centrar en mi posición',
        onPressed: onPressed,
        child: SizedBox.square(
          dimension: 50,
          child: Icon(
            located ? Icons.near_me_rounded : Icons.near_me_outlined,
            size: 22,
            color: located ? AppColors.accent : AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }
}

/// On the web the map's own attribution control ignores margins and ends up
/// under the tab bar, so the credit is repeated here, above it.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0xB306080C),
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '© OpenStreetMap · OpenMapTiles · OpenFreeMap',
          maxLines: 2,
          style: AppTypography.textTheme().labelSmall!.copyWith(
                color: AppColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

/// Draggable glass sheet with a stop's next departures and one-tap origin /
/// destination selection. It floats 8 px off the screen edges, iOS-style.
class _StopSheet extends ConsumerWidget {
  const _StopSheet({required this.stop, required this.scrollController});

  final Stop stop;
  final ScrollController scrollController;

  static Future<void> show(BuildContext context, Stop stop) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the shell, so the tab bar and the mode button don't cover the
      // list.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      // A light dim keeps the selected stop's halo visible above the sheet.
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (sheetContext) {
        final inset = math.max(8.0, MediaQuery.paddingOf(sheetContext).bottom);
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, inset),
            child: _StopSheet(stop: stop, scrollController: controller),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = TransitOperator.fromId(stop.operatorId);
    final opColor = Color(operator.colorHex);
    final departures = ref.watch(departuresForStopProvider(stop));
    final destinationAllowed = canBeDestination(ref, stop);
    final t = AppTypography.textTheme();

    return GlassSurface(
      // The web can't blur the map under the sheet; this kind falls back to
      // a denser tint there.
      kind: GlassKind.overMap,
      radius: 32,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: _Grabber()),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _OperatorDot(color: opColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          operator.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(
                      stop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetAction(
                          label: 'Salir de aquí',
                          icon: Icons.trip_origin_rounded,
                          tint: AppColors.accent,
                          onPressed: () {
                            selectStopAsOrigin(ref, stop);
                            Navigator.of(context).pop();
                            context.go('/');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SheetAction(
                          label: 'Ir hasta aquí',
                          icon: Icons.place_rounded,
                          onPressed: destinationAllowed
                              ? () {
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
                        ),
                      ),
                    ],
                  ),
                  if (!destinationAllowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Para usarla como destino, elige antes un origen de '
                        '${operator.name}.',
                        style: t.bodySmall!.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Próximas salidas',
                          style: t.titleMedium!.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          textStyle: t.labelLarge,
                          padding: const EdgeInsets.only(left: 10, right: 4),
                          minimumSize: const Size(44, 40),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          StopDeparturesScreen.open(context, stop);
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Ver todas'),
                            Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          ...departures.when(
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: _Spinner()),
                ),
              ),
            ],
            error: (_, __) => const [
              _SheetMessage('No se han podido cargar las salidas.'),
            ],
            data: (list) => list.isEmpty
                ? const [_SheetMessage('Sin salidas programadas.')]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      // Concentric with the sheet: 32 − 12.
                      sliver: StopDeparturesCard(
                        departures: list.take(6).toList(),
                        operator: operator,
                        radius: 20,
                      ),
                    ),
                  ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: const ShapeDecoration(
        color: AppColors.darkTextTertiary,
        shape: StadiumBorder(),
      ),
    );
  }
}

/// The operator's colour as a small glowing dot — the same mark as on the
/// map.
class _OperatorDot extends StatelessWidget {
  const _OperatorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8),
        ],
      ),
    );
  }
}

/// Full-width glass action in the stop sheet; [tint] makes it the primary.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tint,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = tint != null
        ? Colors.white
        : (enabled ? AppColors.darkTextPrimary : AppColors.darkTextTertiary);
    return GlassButton(
      kind: GlassKind.overMap,
      // Sits on the glass sheet: one backdrop pass is enough.
      blur: false,
      tint: tint,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.textTheme().labelLarge!.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Text(
          text,
          style: AppTypography.textTheme().bodyMedium!.copyWith(
                color: AppColors.darkTextSecondary,
              ),
        ),
      ),
    );
  }
}
