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

    final stopName = activeStop?.name ?? 'Buscando parada…';

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final stopsAsync = widget.isDestination
        ? ref.watch(reachableDestinationsProvider)
        : ref.watch(stopsForActiveOperatorProvider);
    final opColor = Color(activeOperator.colorHex);
    final isDest = widget.isDestination;
    final t = AppTypography.textTheme();
    final media = MediaQuery.of(context);

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
              Text(
                isDest ? 'Hacia dónde' : 'Desde qué parada',
                style:
                    t.headlineSmall!.copyWith(color: AppColors.darkTextPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                isDest
                    ? 'Destinos directos en la misma línea · ${activeOperator.name}'
                    : 'Toca una parada para ver sus salidas · ${activeOperator.name}',
                style:
                    t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (val) =>
                    setState(() => _query = val.trim().toLowerCase()),
                style: t.bodyLarge!.copyWith(color: AppColors.darkTextPrimary),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    BarikIcons.magnifyingGlass,
                    color: AppColors.darkTextSecondary,
                    size: 20,
                  ),
                  hintText: 'Buscar parada',
                  hintStyle:
                      t.bodyLarge!.copyWith(color: AppColors.darkTextTertiary),
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
                    borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
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
                    final filtered = _query.isEmpty
                        ? stops
                        : stops
                            .where((s) => s.name.toLowerCase().contains(_query))
                            .toList();
                    final currentOrigin =
                        ref.watch(selectedTransitStopProvider);
                    final currentDest =
                        ref.watch(selectedDestinationStopProvider);
                    final showAll = isDest && _query.isEmpty;

                    if (filtered.isEmpty && !showAll) {
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
                              if (isDest) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'No hay paradas en la misma línea sin transbordo.',
                                  textAlign: TextAlign.center,
                                  style: t.bodySmall!.copyWith(
                                    color: AppColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 4),
                      itemCount:
                          showAll ? filtered.length + 1 : filtered.length,
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
                                      selectedDestinationStopProvider.notifier)
                                  .state = null;
                              Navigator.of(context).pop();
                            },
                          );
                        }
                        final stop =
                            showAll ? filtered[index - 1] : filtered[index];
                        final isSelected = isDest
                            ? currentDest?.id == stop.id
                            : currentOrigin?.id == stop.id;
                        final isOtherRole = isDest
                            ? currentOrigin?.id == stop.id
                            : currentDest?.id == stop.id;

                        return _StopOption(
                          icon: isDest
                              ? Icons.flag_rounded
                              : Icons.location_on_rounded,
                          iconColor: isOtherRole
                              ? AppColors.darkTextTertiary
                              : opColor,
                          title: stop.name,
                          subtitle: isOtherRole
                              ? (isDest ? 'Es tu origen' : 'Es tu destino')
                              : null,
                          selected: isSelected,
                          selectedColor: opColor,
                          onTap: () async {
                            if (isDest) {
                              ref
                                  .read(
                                      selectedDestinationStopProvider.notifier)
                                  .state = stop;
                            } else {
                              ref
                                  .read(selectedTransitStopProvider.notifier)
                                  .state = stop;
                              if (currentDest != null) {
                                if (currentDest.id == stop.id) {
                                  ref
                                      .read(selectedDestinationStopProvider
                                          .notifier)
                                      .state = null;
                                } else {
                                  final repo =
                                      ref.read(transitRepositoryProvider);
                                  final reachable =
                                      await repo.getReachableDestinations(
                                    originStopId: stop.id,
                                  );
                                  if (!reachable
                                      .any((s) => s.id == currentDest.id)) {
                                    ref
                                        .read(selectedDestinationStopProvider
                                            .notifier)
                                        .state = null;
                                  }
                                }
                              }
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: t.bodySmall!.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
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
