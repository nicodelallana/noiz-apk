import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/transit_models.dart';
import '../../navigation/transport_mode_fab.dart';
import '../../providers/bus_providers.dart';
import '../../providers/metro_providers.dart';
import '../../widgets/animations/arrival_pulse_indicator.dart';
import '../../widgets/animations/empty_transit_view.dart';
import '../../widgets/map/transit_map_view.dart';
import '../auth/profile_settings_screen.dart';
import '../saved_trips/save_trip_dialog.dart';
import '../saved_trips/saved_trips_screen.dart';

/// Next departures screen for Bizkaia Transit (Noiz).
///
/// Features:
/// - Interactive open vector map (MapLibre GL) centered on active stop.
/// - Fluid animated operator transition: switching to Bus smoothly turns
///   the interface to Bizkaibus Emerald Green (#00843D).
/// - Modern high-contrast typography and designer rounded iconography.
/// - Prominent Lottie arrival pulse animations for imminent departures.
/// - Offline-first GTFS departures with zero generic "horario teórico" tags.
class MetroDeparturesScreen extends ConsumerWidget {
  const MetroDeparturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(transportModeProvider);
    final isBus = mode == TransportMode.bus;
    final primaryColor =
        isBus ? AppColors.bizkaibusGreen : AppColors.metroRed;
    final syncState = ref.watch(scheduleSyncStatusProvider);
    final selectedStation = ref.watch(selectedMetroStationProvider);
    final selectedBusStop = ref.watch(selectedBusStopProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
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
                isBus
                    ? Icons.directions_bus_rounded
                    : Icons.directions_subway_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Noiz',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  isBus ? 'Bizkaibus & Bilbobus' : 'Metro Bilbao',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_rounded),
            tooltip: 'Mis viajes guardados',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedTripsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_rounded),
            tooltip: 'Guardar viaje',
            onPressed: () {
              final activeOrigin = isBus ? selectedBusStop : selectedStation;
              showDialog<void>(
                context: context,
                builder: (_) => SaveTripDialog(initialOrigin: activeOrigin),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.autorenew_rounded),
            tooltip: 'Sincronizar horarios',
            onPressed: () => ref.refresh(scheduleSyncStatusProvider),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Mi cuenta',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: syncState.when(
        loading: () =>
            const _TransitLoadingIndicator(message: 'Sincronizando red...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudo sincronizar el horario:\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.refresh(scheduleSyncStatusProvider),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          // Initialize default station if null
          if (!isBus && selectedStation == null) {
            _initializeDefaultStation(ref);
          }

          return const _TransitScreenContent();
        },
      ),
    );
  }

  void _initializeDefaultStation(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stations = await ref.read(metroStationsProvider.future);
      if (stations.isNotEmpty &&
          ref.read(selectedMetroStationProvider) == null) {
        final defaultStation = stations.firstWhere(
          (s) =>
              s.name.toLowerCase().contains('mamés') ||
              s.name.toLowerCase().contains('mames'),
          orElse: () => stations.first,
        );
        ref.read(selectedMetroStationProvider.notifier).state = defaultStation;
      }
    });
  }
}

/// Content containing Map, Operator Switcher, Stop Selector, Chips and Departures.
class _TransitScreenContent extends ConsumerWidget {
  const _TransitScreenContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(transportModeProvider);
    final isBus = mode == TransportMode.bus;
    final primaryColor =
        isBus ? AppColors.bizkaibusGreen : AppColors.metroRed;

    // Active stop details for Map and Selector
    final metroStation = ref.watch(selectedMetroStationProvider);
    final busStop = ref.watch(selectedBusStopProvider);

    final stopName = isBus
        ? busStop.name
        : (metroStation?.name ?? 'San Mamés');

    final latitude = isBus
        ? (busStop.latitude ?? 43.2628)
        : (metroStation?.latitude ?? 43.2625);

    final longitude = isBus
        ? (busStop.longitude ?? -2.9352)
        : (metroStation?.longitude ?? -2.9495);

    return CustomScrollView(
      slivers: [
        // ── 1. MapLibre GL Vector Map View ──────────────────────────────────
        SliverToBoxAdapter(
          child: TransitMapView(
            latitude: latitude,
            longitude: longitude,
            stationName: stopName,
            height: 200,
            primaryColor: primaryColor,
            isBusMode: isBus,
          ),
        ),

        // ── 2. Dynamic Operator Switcher (Metro vs Bus) ─────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _OperatorPillSwitcher(
              activeMode: mode,
              onModeChanged: (newMode) {
                ref.read(transportModeProvider.notifier).state = newMode;
              },
            ),
          ),
        ),

        // ── 3. High-Contrast Station/Stop Selector Card ────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _StationPickerCard(
              isBus: isBus,
              stopName: stopName,
              primaryColor: primaryColor,
              onTap: () {
                if (isBus) {
                  _openBusStopPicker(context, ref);
                } else {
                  _openMetroStationPicker(context, ref);
                }
              },
            ),
          ),
        ),

        // ── 4. Line Filter Chips ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: isBus ? const _BusLineFilterChips() : const _MetroLineFilterChips(),
        ),

        const SliverToBoxAdapter(
          child: Divider(height: 1, indent: 16, endIndent: 16),
        ),

        // ── 5. Departures List ─────────────────────────────────────────────
        if (isBus)
          const _BusDeparturesSliverList()
        else
          const _MetroDeparturesSliverList(),

        // Extra padding at bottom for FAB & Navbar
        const SliverToBoxAdapter(
          child: SizedBox(height: 84),
        ),
      ],
    );
  }

  void _openMetroStationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _StationSearchModal(),
    );
  }

  void _openBusStopPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _BusStopSearchModal(),
    );
  }
}

/// Smooth sliding operator switcher pill with animated indicator.
class _OperatorPillSwitcher extends StatelessWidget {
  const _OperatorPillSwitcher({
    required this.activeMode,
    required this.onModeChanged,
  });

  final TransportMode activeMode;
  final ValueChanged<TransportMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final isBus = activeMode == TransportMode.bus;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Sliding background indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            alignment: isBus ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: isBus ? AppColors.bizkaibusGreen : AppColors.metroRed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isBus ? AppColors.bizkaibusGreen : AppColors.metroRed)
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Clickable row of options
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onModeChanged(TransportMode.metro),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_subway_rounded,
                          size: 18,
                          color: !isBus ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Metro Bilbao',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !isBus ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onModeChanged(TransportMode.bus),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          size: 18,
                          color: isBus ? Colors.white : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Bizkaibus',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isBus ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
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

/// Floating station / stop selector card with high-contrast text.
class _StationPickerCard extends StatelessWidget {
  const _StationPickerCard({
    required this.isBus,
    required this.stopName,
    required this.primaryColor,
    required this.onTap,
  });

  final bool isBus;
  final String stopName;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBus
                      ? Icons.directions_bus_rounded
                      : Icons.directions_subway_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBus ? 'PARADA SELECCIONADA' : 'ESTACIÓN DE SALIDA',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stopName,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.unfold_more_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Line filter chips for Metro Bilbao (Todas, L1, L2).
class _MetroLineFilterChips extends ConsumerWidget {
  const _MetroLineFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(selectedMetroLineFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: currentFilter == null,
            selectedColor: AppColors.metroRed,
            labelStyle: TextStyle(
              color: currentFilter == null ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            onSelected: (_) =>
                ref.read(selectedMetroLineFilterProvider.notifier).state = null,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const CircleAvatar(
              backgroundColor: Color(0xFFE2001A),
              radius: 6,
            ),
            label: const Text('L1'),
            selected: currentFilter == MetroLine.l1,
            selectedColor: AppColors.metroRed,
            labelStyle: TextStyle(
              color: currentFilter == MetroLine.l1
                  ? Colors.white
                  : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            onSelected: (_) => ref
                .read(selectedMetroLineFilterProvider.notifier)
                .state = MetroLine.l1,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const CircleAvatar(
              backgroundColor: Color(0xFF1D1D1B),
              radius: 6,
            ),
            label: const Text('L2'),
            selected: currentFilter == MetroLine.l2,
            selectedColor: const Color(0xFF1D1D1B),
            labelStyle: TextStyle(
              color: currentFilter == MetroLine.l2
                  ? Colors.white
                  : const Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            onSelected: (_) => ref
                .read(selectedMetroLineFilterProvider.notifier)
                .state = MetroLine.l2,
          ),
        ],
      ),
    );
  }
}

/// Line filter chips for Bizkaibus / Bilbobus.
class _BusLineFilterChips extends ConsumerWidget {
  const _BusLineFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(selectedBusLineFilterProvider);

    final lines = ['Todas', 'A3115', 'A3336', 'A3411', 'A3136', '01'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: lines.map((line) {
          final isAll = line == 'Todas';
          final isSelected = isAll ? currentFilter == null : currentFilter == line;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(line),
              selected: isSelected,
              selectedColor: AppColors.bizkaibusGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              onSelected: (_) {
                ref.read(selectedBusLineFilterProvider.notifier).state =
                    isAll ? null : line;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Departures list for Metro Bilbao.
class _MetroDeparturesSliverList extends ConsumerWidget {
  const _MetroDeparturesSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresState = ref.watch(metroDeparturesStreamProvider);

    return departuresState.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: _TransitLoadingIndicator(
          message: 'Consultando próximas salidas de Metro...',
        ),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar salidas: $e'),
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
                  'No hay más salidas de Metro programadas para este horario.',
              onRetry: () => ref.invalidate(metroDeparturesStreamProvider),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                final departure = departures[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MetroDepartureCard(departure: departure),
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

/// Modern departure card for Metro.
class _MetroDepartureCard extends StatelessWidget {
  const _MetroDepartureCard({required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final isL1 = departure.line == MetroLine.l1;
    final badgeColor = isL1 ? AppColors.metroRed : const Color(0xFF1D1D1B);
    final isImminent = departure.minutesRemaining <= 3;
    final isUpcoming = departure.minutesRemaining <= 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Line Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              departure.line.id,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
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
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      departure.scheduledTimeFormatted,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrival countdown + prominent pulse animation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUpcoming) ...[
                const ArrivalPulseIndicator(size: 22),
                const SizedBox(width: 6),
              ],
              Text(
                departure.minutesRemaining <= 0
                    ? 'Inminente'
                    : '${departure.minutesRemaining} min',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isImminent ? AppColors.metroRed : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Departures list for Bizkaibus.
class _BusDeparturesSliverList extends ConsumerWidget {
  const _BusDeparturesSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresState = ref.watch(busDeparturesStreamProvider);

    return departuresState.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: _TransitLoadingIndicator(
          message: 'Consultando próximas salidas de Bizkaibus...',
        ),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar salidas: $e'),
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
                  'No hay más salidas de Bizkaibus en esta parada.',
              onRetry: () => ref.invalidate(busDeparturesStreamProvider),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                final departure = departures[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BusDepartureCard(departure: departure),
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

/// Modern departure card for Bizkaibus / Bilbobus.
class _BusDepartureCard extends StatelessWidget {
  const _BusDepartureCard({required this.departure});

  final BusDeparture departure;

  @override
  Widget build(BuildContext context) {
    final isBilbobus = departure.operatorName == 'Bilbobus';
    final badgeColor =
        isBilbobus ? const Color(0xFFD92525) : AppColors.bizkaibusGreen;
    final isImminent = departure.minutesRemaining <= 3;
    final isUpcoming = departure.minutesRemaining <= 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Line Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              departure.routeNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Destination and Operator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.destination,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      departure.scheduledTimeFormatted,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        departure.operatorName,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrival countdown + pulse animation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUpcoming) ...[
                const ArrivalPulseIndicator(size: 22),
                const SizedBox(width: 6),
              ],
              Text(
                departure.minutesRemaining <= 0
                    ? 'Inminente'
                    : '${departure.minutesRemaining} min',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color:
                      isImminent ? AppColors.bizkaibusGreen : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lottie vector loading indicator (<50 KB, RepaintBoundary, Reduced Motion aware).
class _TransitLoadingIndicator extends StatelessWidget {
  const _TransitLoadingIndicator({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: reduceMotion
                ? const Icon(
                    Icons.directions_subway_rounded,
                    size: 54,
                    color: AppColors.metroRed,
                  )
                : SizedBox(
                    width: 72,
                    height: 72,
                    child: Lottie.asset(
                      'assets/lottie/metro_loading.json',
                      frameRate: FrameRate.composition,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet modal to search and pick Metro Bilbao stations.
class _StationSearchModal extends ConsumerWidget {
  const _StationSearchModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(metroStationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                hintText: 'Buscar estación de Metro...',
                leading: const Icon(Icons.search_rounded),
                onChanged: (val) {
                  ref.read(stationSearchQueryProvider.notifier).state = val;
                },
              ),
            ),
            Expanded(
              child: stationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (stations) {
                  if (stations.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron estaciones'),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: stations.length,
                    itemBuilder: (ctx, index) {
                      final st = stations[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.metroRed,
                        ),
                        title: Text(
                          st.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: st.lines
                              .map(
                                (line) => Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(line.colorHex),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    line.id,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        onTap: () {
                          ref
                              .read(selectedMetroStationProvider.notifier)
                              .state = st;
                          ref.read(stationSearchQueryProvider.notifier).state =
                              '';
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet modal to search and pick Bizkaibus stops.
class _BusStopSearchModal extends ConsumerWidget {
  const _BusStopSearchModal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(busStopsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Seleccionar Parada de Autobús',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: stops.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, index) {
                  final stop = stops[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.directions_bus_rounded,
                      color: AppColors.bizkaibusGreen,
                    ),
                    title: Text(
                      stop.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Bizkaibus / Bilbobus',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    onTap: () {
                      ref.read(selectedBusStopProvider.notifier).state = stop;
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
