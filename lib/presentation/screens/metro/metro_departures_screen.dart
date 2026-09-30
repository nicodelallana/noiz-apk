import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../domain/models/transit_models.dart';
import '../../providers/metro_providers.dart';
import '../auth/profile_settings_screen.dart';
import '../saved_trips/save_trip_dialog.dart';
import '../saved_trips/saved_trips_screen.dart';

/// Metro Bilbao departures screen.
///
/// Features:
/// - Station picker modal with search
/// - Line filter chips (Todas, L1, L2)
/// - Fluid Lottie loading indicator (<50 KB, RepaintBoundary, Reduced Motion aware)
/// - Live countdown departures list labeled with theoretical schedule
class MetroDeparturesScreen extends ConsumerWidget {
  const MetroDeparturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(scheduleSyncStatusProvider);
    final selectedStation = ref.watch(selectedMetroStationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metro Bilbao'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: 'Mis viajes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedTripsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Guardar viaje',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => SaveTripDialog(initialOrigin: selectedStation),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar horarios',
            onPressed: () => ref.refresh(scheduleSyncStatusProvider),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
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
            const _MetroLoadingIndicator(message: 'Descargando horarios...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'No se pudo sincronizar el horario:\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.refresh(scheduleSyncStatusProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          // If no station is selected, trigger initialization
          if (selectedStation == null) {
            _initializeDefaultStation(ref);
          }

          return const _MetroContent();
        },
      ),
    );
  }

  void _initializeDefaultStation(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final stations = await ref.read(metroStationsProvider.future);
      if (stations.isNotEmpty &&
          ref.read(selectedMetroStationProvider) == null) {
        // Default to San Mamés if found, otherwise first station
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

class _MetroContent extends ConsumerWidget {
  const _MetroContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStation = ref.watch(selectedMetroStationProvider);

    return Column(
      children: [
        // 1. Station selector card
        _StationPickerHeader(
          station: selectedStation,
          onTap: () => _openStationPicker(context, ref),
        ),

        // 2. Line filter chips
        const _LineFilterChips(),

        const Divider(height: 1),

        // 3. Departures stream list
        const Expanded(
          child: _DeparturesList(),
        ),
      ],
    );
  }

  void _openStationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _StationSearchModal(),
    );
  }
}

class _StationPickerHeader extends StatelessWidget {
  const _StationPickerHeader({
    required this.station,
    required this.onTap,
  });

  final Stop? station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2001A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.subway, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estación de salida',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  Text(
                    station?.name ?? 'Seleccionar estación...',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _LineFilterChips extends ConsumerWidget {
  const _LineFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(selectedMetroLineFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: currentFilter == null,
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
            onSelected: (_) => ref
                .read(selectedMetroLineFilterProvider.notifier)
                .state = MetroLine.l2,
          ),
        ],
      ),
    );
  }
}

class _DeparturesList extends ConsumerWidget {
  const _DeparturesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departuresState = ref.watch(metroDeparturesStreamProvider);

    return departuresState.when(
      loading: () => const _MetroLoadingIndicator(
          message: 'Consultando próximas salidas...'),
      error: (e, _) => Center(
        child: Text('Error al cargar salidas: $e'),
      ),
      data: (departures) {
        if (departures.isEmpty) {
          return const Center(
            child: Text(
              'No hay salidas programadas para el horario seleccionado.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: departures.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
          itemBuilder: (ctx, index) {
            final departure = departures[index];
            return _DepartureTile(departure: departure);
          },
        );
      },
    );
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.departure});

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isL1 = departure.line == MetroLine.l1;
    final badgeColor = isL1 ? const Color(0xFFE2001A) : const Color(0xFF1D1D1B);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          departure.line.id,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        departure.headsign,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          Text(departure.scheduledTimeFormatted),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'horario teórico',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            departure.minutesRemaining <= 0
                ? 'Inminente'
                : '${departure.minutesRemaining} min',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: departure.minutesRemaining <= 3
                  ? const Color(0xFFE2001A)
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetroLoadingIndicator extends StatelessWidget {
  const _MetroLoadingIndicator({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // Respect accessibility reduced motion preference
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: reduceMotion
                ? const Icon(Icons.subway, size: 54, color: Color(0xFFE2001A))
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
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

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
                leading: const Icon(Icons.search),
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
                        child: Text('No se encontraron estaciones'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: stations.length,
                    itemBuilder: (ctx, index) {
                      final st = stations[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(st.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: st.lines
                              .map(
                                (line) => Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
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
