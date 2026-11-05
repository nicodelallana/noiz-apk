import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/live_trip_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/barik_icons.dart';
import '../../../core/utils/geo.dart';
import '../../../domain/models/live_trip_models.dart';
import '../../../domain/models/saved_trip_models.dart';
import '../../../domain/models/transit_models.dart';
import '../../providers/transit_providers.dart';
import '../../widgets/animations/empty_transit_view.dart';
import '../../widgets/departure_hero_card.dart';
import '../../widgets/departure_row.dart';
import '../../widgets/glass/content.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/glass/motion.dart';
import '../nearby/nearby_transit_screen.dart';
import '../planner/route_planner_screen.dart';
import '../saved_trips/save_trip_dialog.dart';
import '../simulator/live_activity_simulator_screen.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Home ("Inicio"): the next departures from the selected stop.
///
/// Layout, top to bottom: the stop as a large title (operator above it,
/// glass buttons for save and menu), territory segmented control and
/// operator chips, the origin → destination glass capsule, the next
/// departure as the hero card, the following departures grouped in one
/// card, and the stop on a mini map. Asks for location once and jumps to
/// the nearest stop only on a real GPS fix.
class MetroDeparturesScreen extends ConsumerStatefulWidget {
  const MetroDeparturesScreen({super.key});

  @override
  ConsumerState<MetroDeparturesScreen> createState() =>
      _MetroDeparturesScreenState();
}

class _MetroDeparturesScreenState extends ConsumerState<MetroDeparturesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationAndDetectNearby();
    });
  }

  Future<void> _requestLocationAndDetectNearby() async {
    final loc = await ref.read(resolvedUserLocationProvider.future);
    if (!mounted) return;

    // 1. Determine territory strictly from user GPS coordinates (prevents wrong province from cross-province stops)
    final territory =
        TransitTerritory.territoryFromCoordinates(loc.latitude, loc.longitude);
    ref.read(selectedTerritoryProvider.notifier).state = territory;

    // 2. Select default operator for territory (Metro Bilbao in Bizkaia)
    final defaultOp = TransitTerritory.defaultOperatorFor(territory);
    ref.read(selectedOperatorProvider.notifier).state = defaultOp;

    // 3. Find closest stop belonging to the chosen operator
    final repo = ref.read(transitRepositoryProvider);
    final stops = await repo.getStops(operatorId: defaultOp.id);
    if (stops.isNotEmpty && mounted) {
      final nearest = stops.reduce((a, b) {
        final da = haversineKm(
          loc.latitude,
          loc.longitude,
          a.latitude ?? 0,
          a.longitude ?? 0,
        );
        final db = haversineKm(
          loc.latitude,
          loc.longitude,
          b.latitude ?? 0,
          b.longitude ?? 0,
        );
        return da < db ? a : b;
      });
      ref.read(selectedTransitStopProvider.notifier).state = nearest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: _TransitScreenContent(),
    );
  }
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

void _openStopPicker(
  BuildContext context,
  WidgetRef ref, {
  bool isDestination = false,
}) {
  if (isDestination && ref.read(selectedTransitStopProvider) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selecciona primero una parada de origen'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) =>
        _MultiOperatorStopSearchModal(isDestination: isDestination),
  );
}

/// Scrolling content of the home tab.
class _TransitScreenContent extends ConsumerWidget {
  const _TransitScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final primaryColor = Color(activeOperator.colorHex);
    final activeStop = ref.watch(selectedTransitStopProvider);
    final destinationStop = ref.watch(selectedDestinationStopProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    ref.listen<AsyncValue<List<Departure>>>(departuresForActiveStopProvider, (_, next) {
      final LiveTripState? trip = ref.read(activeLiveTripProvider);
      final deps = next.value;
      if (trip != null && deps != null && deps.isNotEmpty) {
        final hero = deps.firstWhere(
          (d) => d.status != 'cancelled',
          orElse: () => deps.first,
        );
        final following = deps.length > 1 ? deps[1] : null;
        if (DateTime.now().isAfter(trip.arrivalTime.add(const Duration(seconds: 20)))) {
          final updated = trip.copyWith(
            arrivalTime: hero.scheduledTime,
            followingDepartureTime: following?.scheduledTime,
            updatedAt: DateTime.now(),
          );
          ref.read(activeLiveTripProvider.notifier).updateTrip(updated);
        }
      }
    });

    // Guard against cross-operator stop mismatch: ensure active stop always matches active operator
    if (activeStop != null && activeStop.operatorId != activeOperator.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switchOperator(ref, activeOperator);
      });
    }

    final stopName = (activeStop != null && activeStop.operatorId == activeOperator.id)
        ? activeStop.name
        : 'Buscando parada…';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 10, 16, 0),
            child: _Reveal(
              index: 0,
              child: _HomeHeader(
                stopName: stopName,
                operatorName: activeOperator.name,
                operatorColor: primaryColor,
                modeIcon: _iconForMode(activeOperator.mode),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _Reveal(
              index: 1,
              fade: false, // glass
              child: _RouteCapsule(
                originStopName: stopName,
                destStopName: destinationStop?.name,
                operatorColor: primaryColor,
                onTapOrigin: () => _openStopPicker(context, ref),
                onTapDestination: () =>
                    _openStopPicker(context, ref, isDestination: true),
                onSwap: () async {
                  if (activeStop != null && destinationStop != null) {
                    final repo = ref.read(transitRepositoryProvider);
                    final reachable = await repo.getReachableDestinations(
                      originStopId: destinationStop.id,
                    );
                    final canReverse =
                        reachable.any((s) => s.id == activeStop.id);
                    ref.read(selectedTransitStopProvider.notifier).state =
                        destinationStop;
                    ref.read(selectedDestinationStopProvider.notifier).state =
                        canReverse ? activeStop : null;
                  } else if (activeStop != null) {
                    _openStopPicker(context, ref, isDestination: true);
                  }
                },
                onClearDestination: () {
                  HapticFeedback.lightImpact();
                  ref.read(selectedDestinationStopProvider.notifier).state =
                      null;
                },
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: _LineFilterBar(),
        ),

        const _MultiOperatorDeparturesSliverList(),

        // A live map here was a platform view inside the scroll view: on
        // the web every scrolled frame had to re-composite it. A link card
        // to the Mapa tab gives the same way in at no cost.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _MapLinkCard(stopName: stopName, color: primaryColor),
          ),
        ),

        // Room for the floating tab bar.
        SliverToBoxAdapter(
          child: SizedBox(height: 96 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }
}

/// Large-title header: operator (opens the transport selector) above the
/// stop name (opens the stop picker), with glass save and menu buttons.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.stopName,
    required this.operatorName,
    required this.operatorColor,
    required this.modeIcon,
  });

  final String stopName;
  final String operatorName;
  final Color operatorColor;
  final IconData modeIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTypography.textTheme();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(modeIcon, size: 15, color: operatorColor),
                    const SizedBox(width: 6),
                    Text(
                      operatorName,
                      style: t.titleSmall!.copyWith(
                        color: operatorColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Parada: $stopName. Cambiar parada',
                onTap: () => _openStopPicker(context, ref),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _openStopPicker(context, ref),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedSwitcher(
                    duration: Motion.reduced(context)
                        ? Motion.reducedFade
                        : const Duration(milliseconds: 260),
                    child: Text(
                      stopName,
                      key: ValueKey(stopName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.displayMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              GlassButton(
                semanticLabel: 'Guardar esta parada',
                padding: EdgeInsets.zero,
                onPressed: () {
                  final activeStop = ref.read(selectedTransitStopProvider);
                  showDialog<void>(
                    context: context,
                    builder: (_) => SaveTripDialog(initialOrigin: activeStop),
                  );
                },
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.bookmark_add_outlined,
                    size: 21,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _HomeMenu(),
            ],
          ),
        ),
      ],
    );
  }
}

/// "⋯" glass button with the secondary tools.
class _HomeMenu extends StatelessWidget {
  const _HomeMenu();

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(String value, IconData icon, String label,
        {Color color = AppColors.darkTextPrimary}) {
      return PopupMenuItem(
        value: value,
        height: 46,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.textTheme().bodyMedium!.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Herramientas y rutas',
      color: AppColors.darkSurfaceElevated.withValues(alpha: 0.97),
      elevation: 12,
      offset: const Offset(0, 52),
      shape: continuousShape(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorderStrong),
      ),
      onSelected: (value) {
        HapticFeedback.lightImpact();
        switch (value) {
          case 'planner':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const RoutePlannerScreen()),
            );
          case 'nearby':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const NearbyTransitScreen()),
            );
          case 'saved':
            context.go('/saved-trips');
          case 'simulator':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LiveActivitySimulatorScreen(),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        item('planner', BarikIcons.path, 'Rutas paso a paso'),
        item('nearby', BarikIcons.radar, 'Paradas cerca de ti'),
        item('saved', Icons.bookmark_rounded, 'Viajes guardados'),
        // Developer tool: never shipped in release builds.
        if (kDebugMode) ...[
          const PopupMenuDivider(height: 1),
          item('simulator', BarikIcons.broadcast,
              'Simulador Live Activity (debug)',
              color: AppColors.delayedAmber),
        ],
      ],
      child: const IgnorePointer(
        child: GlassSurface(
          radius: 999,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.more_horiz_rounded,
              size: 22,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Origin → destination in one glass capsule (Apple Maps directions style),
/// with a swap button. "Todas las direcciones" when no destination is set.
class _RouteCapsule extends StatelessWidget {
  const _RouteCapsule({
    required this.originStopName,
    required this.destStopName,
    required this.operatorColor,
    required this.onTapOrigin,
    required this.onTapDestination,
    required this.onSwap,
    required this.onClearDestination,
  });

  final String originStopName;
  final String? destStopName;
  final Color operatorColor;
  final VoidCallback onTapOrigin;
  final VoidCallback onTapDestination;
  final VoidCallback onSwap;
  final VoidCallback onClearDestination;

  @override
  Widget build(BuildContext context) {
    final hasDestination = destStopName != null;
    return GlassSurface(
      radius: 24,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _RouteRow(
                  label: 'Desde',
                  value: originStopName,
                  marker: _Dot(color: operatorColor, filled: true),
                  onTap: onTapOrigin,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 46),
                  child: Divider(
                      height: 1, thickness: 0.7, color: AppColors.darkBorder),
                ),
                _RouteRow(
                  label: 'Hacia',
                  value: destStopName ?? 'Todas las direcciones',
                  muted: !hasDestination,
                  marker: _Dot(
                    color: hasDestination
                        ? AppColors.darkTextPrimary
                        : AppColors.darkTextTertiary,
                    filled: false,
                  ),
                  onTap: onTapDestination,
                  trailing: hasDestination
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.darkTextSecondary,
                          tooltip: 'Ver todas las direcciones',
                          onPressed: onClearDestination,
                        )
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              label: 'Intercambiar origen y destino',
              onTap: onSwap,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSwap();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: CircleBorder(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    size: 20,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.label,
    required this.value,
    required this.marker,
    required this.onTap,
    this.trailing,
    this.muted = false,
  });

  final String label;
  final String value;
  final Widget marker;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return Semantics(
      button: true,
      label: '$label $value',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              SizedBox(width: 46, child: Center(child: marker)),
              SizedBox(
                width: 52,
                child: Text(
                  label,
                  style:
                      t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium!.copyWith(
                    fontSize: 16,
                    color: muted
                        ? AppColors.darkTextSecondary
                        : AppColors.darkTextPrimary,
                    fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
        boxShadow: filled
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
    );
  }
}

/// "See it on the map" entry: opens the Mapa tab.
class _MapLinkCard extends StatelessWidget {
  const _MapLinkCard({required this.stopName, required this.color});

  final String stopName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      onTap: () => context.go('/map'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.85),
                  color.withValues(alpha: 0.45)
                ],
              ),
              shape: continuousShape(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ver en el mapa',
                  style:
                      t.titleMedium!.copyWith(color: AppColors.darkTextPrimary),
                ),
                Text(
                  'Paradas y salidas alrededor de $stopName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}

/// Hero card for the next departure, then the rest grouped in one card.
class _MultiOperatorDeparturesSliverList extends ConsumerWidget {
  const _MultiOperatorDeparturesSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresState = ref.watch(departuresForActiveStopProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeStop = ref.watch(selectedTransitStopProvider);

    return departuresState.when(
      // The minute tick recomputes departures: keep the list, no skeleton.
      skipLoadingOnReload: true,
      loading: () => const SliverToBoxAdapter(child: _HeroSkeleton()),
      error: (error, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar los horarios: $error',
            style: const TextStyle(color: AppColors.disruptedRed),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (departures) {
        if (departures.isEmpty) {
          return SliverToBoxAdapter(
            child: EmptyTransitView(
              title: 'Sin próximas salidas',
              message:
                  'No hay más salidas programadas para ${activeStop?.name ?? "esta parada"}.',
              onRetry: () => ref.invalidate(departuresForActiveStopProvider),
            ),
          );
        }

        // The hero is the next train that actually runs.
        final hero = departures.firstWhere(
          (d) => d.status != 'cancelled',
          orElse: () => departures.first,
        );
        final rest = [
          for (final d in departures)
            if (!identical(d, hero)) d
        ];
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                // The hero animates; isolate its repaints from the list.
                child: RepaintBoundary(
                  child: _Reveal(
                    index: 3,
                    child: DepartureHeroCard(
                      departure: hero,
                      operator: activeOperator,
                      originName: activeStop?.name ?? hero.stationName,
                      followingDeparture: rest.isEmpty ? null : rest.first,
                    ),
                  ),
                ),
              ),
            ),
            if (rest.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  'Más salidas',
                  subtitle: rest.any((d) => d.isRealtime)
                      ? 'En directo · datos oficiales del operador'
                      : 'Horario programado',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: DecoratedSliver(
                  decoration: ShapeDecoration(
                    color: const Color(0xF214161C),
                    shape: continuousShape(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    sliver: SliverFixedExtentList.builder(
                      itemExtent: DepartureRow.extentOf(context),
                      itemCount: rest.length,
                      itemBuilder: (ctx, index) => DepartureRow(
                        departure: rest[index],
                        operator: activeOperator,
                        divider: index > 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Placeholder in the hero's shape while the timetable loads.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SurfaceCard(
        radius: 28,
        child: SizedBox(
          height: 210,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrance: content rises 8 px (and fades, unless it contains glass),
/// staggered 35 ms by [index]. Skipped under reduce-motion.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child, this.fade = true});

  final int index;
  final bool fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = 35 * index;
    final total = 280 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) {
        final moved = Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: child,
        );
        return fade ? Opacity(opacity: v, child: moved) : moved;
      },
      child: child,
    );
  }
}

/// Horizontal filter pills for the lines served by the active stop (e.g. A3336, A2336, L1, L2).
class _LineFilterBar extends ConsumerWidget {
  const _LineFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStop = ref.watch(selectedTransitStopProvider);
    final activeOp = ref.watch(selectedOperatorProvider);
    if (activeStop == null || activeStop.operatorId != activeOp.id) {
      return const SizedBox.shrink();
    }

    final linesAsync = ref.watch(servedLinesForActiveStopProvider);
    return linesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (lines) {
        if (lines.length <= 1) {
          return const SizedBox.shrink();
        }

        final selectedLine = ref.watch(selectedLineFilterProvider);
        final opColor = Color(activeOp.colorHex);
        final t = AppTypography.textTheme();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lines.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                if (idx == 0) {
                  final isAllSelected = selectedLine == null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedLineFilterProvider.notifier).state =
                          null;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isAllSelected
                            ? opColor.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAllSelected
                              ? opColor
                              : Colors.white.withValues(alpha: 0.12),
                          width: isAllSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Todas las líneas',
                          style: t.labelMedium!.copyWith(
                            color: isAllSelected
                                ? Colors.white
                                : AppColors.darkTextSecondary,
                            fontWeight: isAllSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final line = lines[idx - 1];
                final isSelected = selectedLine == line;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isSelected) {
                      ref.read(selectedLineFilterProvider.notifier).state =
                          null;
                    } else {
                      ref.read(selectedLineFilterProvider.notifier).state =
                          line;
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? opColor.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? opColor
                            : Colors.white.withValues(alpha: 0.12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? opColor
                                  : AppColors.darkTextTertiary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            line,
                            style: t.labelMedium!.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.darkTextPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
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
        );
      },
    );
  }
}

/// Glass sheet to search and pick a stop of the active operator, as origin
/// or as destination ("Todas las direcciones" first).
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
  Stop? _selectedStopForLines;
  List<String>? _availableLines;
  bool _loadingLines = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectLineAndFinish(Stop stop, String? line) async {
    ref.read(selectedTransitStopProvider.notifier).state = stop;
    ref.read(selectedLineFilterProvider.notifier).state = line;
    final currentDest = ref.read(selectedDestinationStopProvider);
    if (currentDest != null) {
      if (currentDest.id == stop.id) {
        ref.read(selectedDestinationStopProvider.notifier).state = null;
      } else {
        final repo = ref.read(transitRepositoryProvider);
        final reachable = await repo.getReachableDestinations(
          originStopId: stop.id,
          lineFilter: line,
        );
        if (!reachable.any((s) => s.id == currentDest.id)) {
          ref.read(selectedDestinationStopProvider.notifier).state = null;
        }
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final isDest = widget.isDestination;
    final stopsAsync = isDest
        ? ref.watch(reachableDestinationsSearchProvider(_query))
        : ref.watch(stopsForActiveOperatorSearchProvider(_query));
    final t = AppTypography.textTheme();
    final media = MediaQuery.of(context);
    final opColor = Color(activeOperator.colorHex);

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + media.viewInsets.bottom),
      child: GlassSurface(
        blur: true,
        radius: 36,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // STEP 2: Line selection for the chosen stop
              if (_selectedStopForLines != null) ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.darkTextPrimary,
                      ),
                      onPressed: () => setState(() {
                        _selectedStopForLines = null;
                        _availableLines = null;
                      }),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Qué línea vas a coger?',
                            style: t.headlineSmall!
                                .copyWith(color: AppColors.darkTextPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedStopForLines!.name} · ${activeOperator.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall!
                                .copyWith(color: AppColors.darkTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: media.size.height * 0.55),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: (_availableLines?.length ?? 0) + 1,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(left: 44),
                      child: Divider(
                        height: 1,
                        thickness: 0.7,
                        color: AppColors.darkBorder,
                      ),
                    ),
                    itemBuilder: (ctx, index) {
                      if (index == 0) {
                        return _StopOption(
                          icon: Icons.all_inclusive_rounded,
                          iconColor: AppColors.darkTextSecondary,
                          title: 'Todas las líneas',
                          subtitle: 'Ver todas las salidas de esta parada',
                          selected:
                              ref.watch(selectedLineFilterProvider) == null,
                          selectedColor: AppColors.accent,
                          onTap: () => _selectLineAndFinish(
                              _selectedStopForLines!, null),
                        );
                      }
                      final line = _availableLines![index - 1];
                      final isSelected =
                          ref.watch(selectedLineFilterProvider) == line;
                      return _StopOption(
                        icon: _iconForMode(activeOperator.mode),
                        iconColor: opColor,
                        title: 'Línea $line',
                        subtitle: 'Filtrar salidas para la línea $line',
                        selected: isSelected,
                        selectedColor: opColor,
                        onTap: () => _selectLineAndFinish(
                            _selectedStopForLines!, line),
                      );
                    },
                  ),
                ),
              ] else ...[
                // STEP 1: Stop Search
                Text(
                  isDest ? 'Hacia dónde' : 'Desde qué parada',
                  style: t.headlineSmall!
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  isDest
                      ? 'Destinos directos · ${activeOperator.name}'
                      : (_query.isEmpty
                          ? 'Toca una parada o busca por nombre · ${activeOperator.name}'
                          : 'Buscando en ${activeOperator.name}'),
                  style:
                      t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _query = val.trim().toLowerCase()),
                  style:
                      t.bodyLarge!.copyWith(color: AppColors.darkTextPrimary),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      BarikIcons.magnifyingGlass,
                      color: AppColors.darkTextSecondary,
                      size: 20,
                    ),
                    hintText: isDest
                        ? 'Nombre de parada o destino (ej: Bilbao)...'
                        : 'Nombre de parada o calle (ej: Muskiz)...',
                    hintStyle: t.bodyMedium!
                        .copyWith(color: AppColors.darkTextTertiary),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide:
                          BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
                if (_loadingLines)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      color: AppColors.accent,
                    ),
                  )
                else
                  const SizedBox(height: 8),
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: media.size.height * 0.55),
                  child: stopsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No se pudieron cargar las paradas: $e',
                        style: const TextStyle(color: AppColors.disruptedRed),
                      ),
                    ),
                    data: (stops) {
                      final currentOrigin =
                          ref.watch(selectedTransitStopProvider);
                      final currentDest =
                          ref.watch(selectedDestinationStopProvider);
                      final showAll = isDest && _query.isEmpty;

                      if (stops.isEmpty && !showAll) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 28, horizontal: 16),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDest
                                      ? Icons.alt_route_rounded
                                      : BarikIcons.magnifyingGlass,
                                  size: 36,
                                  color: AppColors.darkTextTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isDest
                                      ? 'Sin destinos directos'
                                      : 'Ninguna parada coincide',
                                  style: t.titleMedium!.copyWith(
                                    color: AppColors.darkTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isDest
                                      ? 'No hay paradas en la misma línea sin transbordo.'
                                      : 'Prueba con otro nombre de parada o calle.',
                                  textAlign: TextAlign.center,
                                  style: t.bodySmall!.copyWith(
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 4),
                        itemCount:
                            showAll ? stops.length + 1 : stops.length,
                        separatorBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(left: 44),
                          child: Divider(
                            height: 1,
                            thickness: 0.7,
                            color: AppColors.darkBorder,
                          ),
                        ),
                        itemBuilder: (ctx, index) {
                          if (showAll && index == 0) {
                            return _StopOption(
                              icon: Icons.all_inclusive_rounded,
                              iconColor: AppColors.darkTextSecondary,
                              title: 'Todas las direcciones',
                              subtitle: 'Todas las salidas desde el origen',
                              selected: currentDest == null,
                              selectedColor: AppColors.accent,
                              onTap: () {
                                ref
                                    .read(
                                        selectedDestinationStopProvider
                                            .notifier)
                                    .state = null;
                                Navigator.of(context).pop();
                              },
                            );
                          }
                          final stop =
                              showAll ? stops[index - 1] : stops[index];
                          final stopOperator =
                              TransitOperator.fromId(stop.operatorId);
                          final isSelected = isDest
                              ? currentDest?.id == stop.id
                              : currentOrigin?.id == stop.id;
                          final isOtherRole = isDest
                              ? currentOrigin?.id == stop.id
                              : currentDest?.id == stop.id;
                          final stopColor = Color(stopOperator.colorHex);

                          return _StopOption(
                            icon: isDest
                                ? Icons.flag_rounded
                                : Icons.location_on_rounded,
                            iconColor: isOtherRole
                                ? AppColors.darkTextTertiary
                                : stopColor,
                            title: stop.name,
                            operatorName: stopOperator == activeOperator
                                ? null
                                : stopOperator.name,
                            operatorColor: stopColor,
                            subtitle: isOtherRole
                                ? (isDest ? 'Es tu origen' : 'Es tu destino')
                                : null,
                            selected: isSelected,
                            selectedColor: stopColor,
                            onTap: () async {
                              if (isDest) {
                                ref
                                    .read(
                                        selectedDestinationStopProvider
                                            .notifier)
                                    .state = stop;
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } else {
                                setState(() => _loadingLines = true);
                                final repo =
                                    ref.read(transitRepositoryProvider);
                                final lines = await repo
                                    .getServedLinesForStation(stop.id);
                                if (!mounted) return;
                                setState(() => _loadingLines = false);

                                if (lines.length > 1) {
                                  setState(() {
                                    _selectedStopForLines = stop;
                                    _availableLines = lines;
                                  });
                                } else {
                                  await _selectLineAndFinish(
                                      stop, lines.firstOrNull);
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StopOption extends StatelessWidget {
  const _StopOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    this.subtitle,
    this.operatorName,
    this.operatorColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? operatorName;
  final Color? operatorColor;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            SizedBox(width: 44, child: Icon(icon, size: 20, color: iconColor)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: t.bodyLarge!.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (operatorName != null || subtitle != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (operatorName != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (operatorColor ?? AppColors.accent)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (operatorColor ?? AppColors.accent)
                                      .withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                operatorName!,
                                style: t.labelSmall!.copyWith(
                                  color: operatorColor ?? AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (subtitle != null)
                            Expanded(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall!.copyWith(
                                  color: AppColors.darkTextSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child:
                    Icon(Icons.check_rounded, color: selectedColor, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}
