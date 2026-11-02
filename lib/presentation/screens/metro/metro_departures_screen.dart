import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/barik_icons.dart';
import '../../../domain/models/saved_trip_models.dart';
import '../../../domain/models/transit_models.dart';
import '../../navigation/transport_selector_sheet.dart';
import '../../providers/transit_providers.dart';
import '../../widgets/animations/arrival_pulse_indicator.dart';
import '../../widgets/animations/empty_transit_view.dart';
import '../../widgets/departure_hero_card.dart';
import '../../widgets/map/transit_map_view.dart';
import '../nearby/nearby_transit_screen.dart';
import '../planner/route_planner_screen.dart';
import '../saved_trips/save_trip_dialog.dart';
import '../simulator/live_activity_simulator_screen.dart';

/// Next departures screen for Barik Transit.
///
/// Features:
/// - Fully multi-operator & province-aware across Bizkaia, Gipuzkoa, and Araba.
/// - Prompts for location permission on launch and auto-detects nearest stop.
/// - Seamless theme transitions adapting to the active operator's official brand color.
/// - MapLibre GL vector map centered dynamically on the active station.
/// - High-contrast Midnight dark UI tokens with zero misplaced white cards.
/// - Next departure hero card with lock-screen follow action and Lottie pulse.
/// - Full offline GTFS schedules across all 13 operators of Euskadi.
class MetroDeparturesScreen extends ConsumerStatefulWidget {
  const MetroDeparturesScreen({super.key});

  @override
  ConsumerState<MetroDeparturesScreen> createState() =>
      _MetroDeparturesScreenState();
}

class _MetroDeparturesScreenState
    extends ConsumerState<MetroDeparturesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationAndDetectNearby();
    });
  }

  Future<void> _requestLocationAndDetectNearby() async {
    final locService = ref.read(locationServiceProvider);
    final granted = await locService.requestPermission();
    if (granted && mounted) {
      final loc = await locService.getCurrentLocation();
      if (loc != null && mounted) {
        ref.read(userLocationProvider.notifier).state = loc;
        // Find nearest stop for active operator
        final stops = await ref.read(stopsForActiveOperatorProvider.future);
        if (stops.isNotEmpty && mounted) {
          final nearest = stops.reduce((a, b) {
            final aLat = a.latitude ?? 0.0;
            final aLon = a.longitude ?? 0.0;
            final bLat = b.latitude ?? 0.0;
            final bLon = b.longitude ?? 0.0;
            final da = (aLat - loc.latitude) * (aLat - loc.latitude) +
                (aLon - loc.longitude) * (aLon - loc.longitude);
            final db = (bLat - loc.latitude) * (bLat - loc.latitude) +
                (bLon - loc.longitude) * (bLon - loc.longitude);
            return da < db ? a : b;
          });
          ref.read(selectedTransitStopProvider.notifier).state = nearest;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final primaryColor = Color(activeOperator.colorHex);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => TransportSelectorBottomSheet.show(context),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForMode(activeOperator.mode),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barik',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.5,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        activeOperator.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Guardar esta parada',
            onPressed: () {
              HapticFeedback.lightImpact();
              final activeStop = ref.read(selectedTransitStopProvider);
              showDialog<void>(
                context: context,
                builder: (_) => SaveTripDialog(
                  initialOrigin: activeStop,
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Herramientas y rutas',
            color: AppColors.darkSurfaceElevated,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.darkBorder),
            ),
            onSelected: (value) {
              HapticFeedback.lightImpact();
              switch (value) {
                case 'planner':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RoutePlannerScreen(),
                    ),
                  );
                case 'nearby':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NearbyTransitScreen(),
                    ),
                  );
                case 'simulator':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LiveActivitySimulatorScreen(),
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'planner',
                child: Row(
                  children: [
                    Icon(BarikIcons.path, size: 20, color: AppColors.darkTextPrimary),
                    SizedBox(width: 12),
                    Text(
                      'Rutas paso a paso',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'nearby',
                child: Row(
                  children: [
                    Icon(BarikIcons.radar, size: 20, color: AppColors.darkTextPrimary),
                    SizedBox(width: 12),
                    Text(
                      'Paradas cerca de ti',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'simulator',
                child: Row(
                  children: [
                    Icon(BarikIcons.broadcast, size: 20, color: AppColors.delayedAmber),
                    SizedBox(width: 12),
                    Text(
                      'Simulador Live Activity',
                      style: TextStyle(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: const _TransitScreenContent(),
    );
  }

  IconData _iconForMode(TransitModeType mode) {
    return switch (mode) {
      TransitModeType.metro => BarikIcons.subway,
      TransitModeType.train => BarikIcons.train,
      TransitModeType.tram => BarikIcons.tram,
      TransitModeType.bus => BarikIcons.bus,
      TransitModeType.funicular => BarikIcons.cableCar,
    };
  }
}

/// Content containing Territory/Operator Selector, Map, Stop Selector, and Departures.
class _TransitScreenContent extends ConsumerWidget {
  const _TransitScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final primaryColor = Color(activeOperator.colorHex);
    final activeStop = ref.watch(selectedTransitStopProvider);
    final destinationStop = ref.watch(selectedDestinationStopProvider);

    final stopName = activeStop?.name ?? 'Cargando parada...';
    final destName = destinationStop?.name ?? 'Todas las direcciones';
    final latitude = activeStop?.latitude ?? 43.2625;
    final longitude = activeStop?.longitude ?? -2.9350;

    return CustomScrollView(
      slivers: [
        // ── 0. Territory & Multi-Operator Selector Bar ───────────────────
        const SliverToBoxAdapter(
          child: _TerritoryAndOperatorChipsHeader(),
        ),

        // ── 1. MapLibre GL Vector Map View ──────────────────────────────────
        SliverToBoxAdapter(
          child: TransitMapView(
            latitude: latitude,
            longitude: longitude,
            stationName: stopName,
            height: 180,
            primaryColor: primaryColor,
          ),
        ),

        // ── 2. Origin-Destination Station Selector Card ───────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _OriginDestinationSelectorCard(
              originStopName: stopName,
              destStopName: destName,
              operatorName: activeOperator.name,
              primaryColor: primaryColor,
              mode: activeOperator.mode,
              hasDestination: destinationStop != null,
              onTapOrigin: () => _openStopPicker(context, ref, isDestination: false),
              onTapDestination: () => _openStopPicker(context, ref, isDestination: true),
              onSwap: () {
                if (activeStop != null && destinationStop != null) {
                  final tmp = activeStop;
                  ref.read(selectedTransitStopProvider.notifier).state = destinationStop;
                  ref.read(selectedDestinationStopProvider.notifier).state = tmp;
                } else if (activeStop != null && destinationStop == null) {
                  _openStopPicker(context, ref, isDestination: true);
                }
              },
              onClearDestination: () {
                HapticFeedback.lightImpact();
                ref.read(selectedDestinationStopProvider.notifier).state = null;
              },
            ),
          ),
        ),

        // ── Active Direction Filter Banner ──
        if (destinationStop != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded, size: 14, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mostrando salidas de ${activeStop?.name ?? "origen"} hacia ${destinationStop.name}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(selectedDestinationStopProvider.notifier).state = null;
                      },
                      child: const Text(
                        'Ver todas',
                        style: TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(
          child: Divider(
            height: 14,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.darkBorder,
          ),
        ),

        // ── 3. Departures List ─────────────────────────────────────────────
        const _MultiOperatorDeparturesSliverList(),

        // Extra padding at bottom for FAB & Navbar
        const SliverToBoxAdapter(
          child: SizedBox(height: 96),
        ),
      ],
    );
  }

  void _openStopPicker(BuildContext context, WidgetRef ref, {bool isDestination = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiOperatorStopSearchModal(isDestination: isDestination),
    );
  }
}

/// Territory and Operator selector bar covering all of Euskadi.
class _TerritoryAndOperatorChipsHeader extends ConsumerWidget {
  const _TerritoryAndOperatorChipsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territory = ref.watch(selectedTerritoryProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);
    final operators = ref.watch(operatorListProvider);
    final opColor = Color(activeOperator.colorHex);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Province / Territory Segmented Bar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: TransitTerritory.values.map((t) {
                final isSel = t == territory;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedTerritoryProvider.notifier).state = t;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel ? opColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        t.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppColors.darkTextSecondary,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Operator Selector Carousel
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: operators.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final op = operators[index];
                final isSel = op == activeOperator;
                final thisOpColor = Color(op.colorHex);

                return Material(
                  color: isSel
                      ? thisOpColor.withValues(alpha: 0.18)
                      : AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(selectedOperatorProvider.notifier).state = op;
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? thisOpColor : AppColors.darkBorder,
                          width: isSel ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: thisOpColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            op.name,
                            style: TextStyle(
                              color: isSel ? Colors.white : AppColors.darkTextPrimary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12.5,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Origin-Destination station selector card styled in Midnight theme.
/// Allows selecting both origin and destination stops ("elegir de qué parada a qué parada").
class _OriginDestinationSelectorCard extends StatelessWidget {
  const _OriginDestinationSelectorCard({
    required this.originStopName,
    required this.destStopName,
    required this.operatorName,
    required this.primaryColor,
    required this.mode,
    required this.onTapOrigin,
    required this.onTapDestination,
    required this.onSwap,
    required this.hasDestination,
    required this.onClearDestination,
  });

  final String originStopName;
  final String destStopName;
  final String operatorName;
  final Color primaryColor;
  final TransitModeType mode;
  final VoidCallback onTapOrigin;
  final VoidCallback onTapDestination;
  final VoidCallback onSwap;
  final bool hasDestination;
  final VoidCallback onClearDestination;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorderStrong, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── 1. Origin Stop Row ──
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapOrigin();
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORIGEN · $operatorName'.toUpperCase(),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          originStopName,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.darkTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more_rounded,
                    color: AppColors.darkTextSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Divider with Centered Swap Button ──
          Stack(
            alignment: Alignment.center,
            children: [
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.darkBorder,
                indent: 52,
                endIndent: 52,
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSwap();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBorderStrong),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.darkTextPrimary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          // ── 2. Destination Stop Row ──
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTapDestination();
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hasDestination
                          ? AppColors.realtimeGreen.withValues(alpha: 0.18)
                          : AppColors.darkSurfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasDestination
                            ? AppColors.realtimeGreen
                            : AppColors.darkBorderStrong,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        hasDestination
                            ? Icons.flag_rounded
                            : Icons.near_me_outlined,
                        size: 16,
                        color: hasDestination
                            ? AppColors.realtimeGreen
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESTINO / DIRECCIÓN'.toUpperCase(),
                          style: TextStyle(
                            color: hasDestination
                                ? AppColors.realtimeGreen
                                : AppColors.darkTextSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destStopName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasDestination
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: -0.3,
                            color: hasDestination
                                ? AppColors.darkTextPrimary
                                : AppColors.darkTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (hasDestination)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.darkTextSecondary,
                        size: 18,
                      ),
                      tooltip: 'Ver todas las direcciones',
                      onPressed: onClearDestination,
                    )
                  else
                    const Icon(
                      Icons.unfold_more_rounded,
                      color: AppColors.darkTextSecondary,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-Operator departures sliver list.
class _MultiOperatorDeparturesSliverList extends ConsumerWidget {
  const _MultiOperatorDeparturesSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresState = ref.watch(departuresForActiveStopProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeStop = ref.watch(selectedTransitStopProvider);

    return departuresState.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al cargar horarios: $error',
              style: const TextStyle(color: AppColors.disruptedRed),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (departures) {
        if (departures.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyTransitView(
              title: 'Sin próximas salidas',
              message:
                  'No hay más salidas programadas para ${activeStop?.name ?? "esta parada"}.',
              onRetry: () => ref.invalidate(departuresForActiveStopProvider),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                final departure = departures[index];
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DepartureHeroCard(
                      departure: departure,
                      operator: activeOperator,
                      originName: activeStop?.name ?? departure.stationName,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MultiOperatorDepartureCard(
                    departure: departure,
                    operator: activeOperator,
                  ),
                );
              },
              childCount: departures.length,
            ),
          ),
        );
      },
    );
  }
}

/// Departure card in Midnight dark theme.
class _MultiOperatorDepartureCard extends StatelessWidget {
  const _MultiOperatorDepartureCard({
    required this.departure,
    required this.operator,
  });

  final Departure departure;
  final TransitOperator operator;

  @override
  Widget build(BuildContext context) {
    final opColor = Color(operator.colorHex);
    final isImminent = departure.minutesRemaining <= 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isImminent
              ? AppColors.realtimeGreen.withValues(alpha: 0.45)
              : AppColors.darkBorder,
          width: isImminent ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Line Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: opColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              departure.lineCode.isNotEmpty ? departure.lineCode : departure.line.id,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Destination and Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.headsign,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Salida programada: ${departure.scheduledTimeFormatted}',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Minutes Remaining + Real-time indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isImminent) ...[
                    const ArrivalPulseIndicator(size: 20),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    '${departure.minutesRemaining} min',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isImminent
                          ? AppColors.realtimeGreen
                          : AppColors.darkTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: departure.isRealtime
                      ? AppColors.realtimeGreen.withValues(alpha: 0.12)
                      : AppColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: departure.isRealtime
                        ? AppColors.realtimeGreen.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  departure.isRealtime ? 'En directo' : 'Según horario',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: departure.isRealtime
                        ? AppColors.realtimeGreen
                        : AppColors.darkTextSecondary,
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

/// Modal sheet to search and pick any stop for the active operator (origin or destination).
class _MultiOperatorStopSearchModal extends ConsumerStatefulWidget {
  const _MultiOperatorStopSearchModal({this.isDestination = false});

  final bool isDestination;

  @override
  ConsumerState<_MultiOperatorStopSearchModal> createState() =>
      _MultiOperatorStopSearchModalState();
}

class _MultiOperatorStopSearchModalState
    extends ConsumerState<_MultiOperatorStopSearchModal> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final stopsAsync = ref.watch(stopsForActiveOperatorProvider);
    final opColor = Color(activeOperator.colorHex);
    final isDest = widget.isDestination;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorderStrong, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              isDest
                  ? 'Elige destino o dirección (${activeOperator.name})'
                  : 'Parada de origen (${activeOperator.name})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isDest
                  ? 'Filtra salidas de qué parada a qué parada'
                  : 'Toca una estación para ver sus próximas salidas',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Search box
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  BarikIcons.magnifyingGlass,
                  color: AppColors.darkTextSecondary,
                ),
                hintText: isDest
                    ? 'Buscar estación de destino...'
                    : 'Buscar estación de origen...',
                hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
                filled: true,
                fillColor: AppColors.darkSurfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Stops list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: stopsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar paradas: $e',
                    style: const TextStyle(color: AppColors.disruptedRed),
                  ),
                ),
                data: (stops) {
                  final filtered = _query.isEmpty
                      ? stops
                      : stops
                          .where((s) => s.name.toLowerCase().contains(_query))
                          .toList();

                  final currentOrigin = ref.watch(selectedTransitStopProvider);
                  final currentDest = ref.watch(selectedDestinationStopProvider);

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: (isDest && _query.isEmpty)
                        ? filtered.length + 1
                        : filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.darkBorder,
                    ),
                    itemBuilder: (ctx, index) {
                      // Top item in destination picker: "Todas las direcciones"
                      if (isDest && _query.isEmpty && index == 0) {
                        final isSelected = currentDest == null;
                        return ListTile(
                          leading: const Icon(
                            Icons.all_inclusive_rounded,
                            color: AppColors.realtimeGreen,
                          ),
                          title: const Text(
                            'Todas las direcciones',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Ver todas las salidas desde la parada de origen',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: AppColors.realtimeGreen)
                              : null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(selectedDestinationStopProvider.notifier).state = null;
                            Navigator.of(context).pop();
                          },
                        );
                      }

                      final stop = (isDest && _query.isEmpty)
                          ? filtered[index - 1]
                          : filtered[index];

                      final isSelected = isDest
                          ? currentDest?.id == stop.id
                          : currentOrigin?.id == stop.id;

                      final isOtherRole = isDest
                          ? currentOrigin?.id == stop.id
                          : currentDest?.id == stop.id;

                      return ListTile(
                        leading: Icon(
                          isDest ? Icons.flag_rounded : Icons.location_on_rounded,
                          color: isSelected
                              ? opColor
                              : (isOtherRole
                                  ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                                  : AppColors.darkTextSecondary),
                        ),
                        title: Text(
                          stop.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? opColor
                                : AppColors.darkTextPrimary,
                          ),
                        ),
                        subtitle: isOtherRole
                            ? Text(
                                isDest
                                    ? '(Estación de origen actual)'
                                    : '(Estación de destino actual)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.darkTextSecondary,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(Icons.check_rounded, color: opColor)
                            : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (isDest) {
                            ref
                                .read(selectedDestinationStopProvider.notifier)
                                .state = stop;
                          } else {
                            ref
                                .read(selectedTransitStopProvider.notifier)
                                .state = stop;
                            if (currentDest?.id == stop.id) {
                              ref
                                  .read(selectedDestinationStopProvider.notifier)
                                  .state = null;
                            }
                          }
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
