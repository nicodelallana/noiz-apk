import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/saved_trip_models.dart';
import '../../providers/saved_trips_providers.dart';
import '../../widgets/animations/empty_transit_view.dart';
import 'save_trip_dialog.dart';

/// "Mis viajes" screen displaying user bookmarked commutes with next departures.
class SavedTripsScreen extends ConsumerWidget {
  const SavedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(savedTripsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Viajes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar viajes',
            onPressed: () =>
                ref.read(savedTripsControllerProvider.notifier).syncRemote(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Guardar viaje'),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (_) => const SaveTripDialog(),
          );
        },
      ),
      body: tripsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('Error al cargar viajes: $e')),
        data: (trips) {
          if (trips.isEmpty) {
            return const EmptyTransitView(
              title: 'No tienes viajes guardados',
              message:
                  'Guarda tus trayectos habituales (como Bagatza ⇄ Kabiezes) para ver las próximas salidas de un vistazo.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final trip = trips[index];
              return _SavedTripCard(trip: trip);
            },
          );
        },
      ),
    );
  }
}

class _SavedTripCard extends ConsumerWidget {
  const _SavedTripCard({required this.trip});

  final SavedTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextDepartureAsync = ref.watch(savedTripNextDepartureProvider(trip));
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(savedTripsControllerProvider.notifier).deleteTrip(trip.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viaje "${trip.name}" eliminado.')),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and Operator Tag
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(trip.operator.colorHex),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trip.operator.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      trip.widgetEnabled
                          ? Icons.widgets
                          : Icons.widgets_outlined,
                      color: trip.widgetEnabled
                          ? theme.colorScheme.primary
                          : Colors.grey,
                      size: 20,
                    ),
                    tooltip: trip.widgetEnabled
                        ? 'Activado en Widget'
                        : 'Desactivado en Widget',
                    onPressed: () {
                      ref
                          .read(savedTripsControllerProvider.notifier)
                          .toggleWidget(trip.id, !trip.widgetEnabled);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Route endpoints
              Row(
                children: [
                  const Icon(Icons.trip_origin, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    trip.originStopName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.destStopName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Live countdown preview
              nextDepartureAsync.when(
                loading: () => const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Calculando próxima salida...',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                error: (_, __) => const Text(
                  'Próxima salida no disponible',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                data: (departure) {
                  if (departure == null) {
                    return const Text(
                      'No hay salidas programadas en las próximas horas',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Salida a las ${departure.scheduledTimeFormatted}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: departure.minutesRemaining <= 3
                              ? const Color(0xFFE2001A).withValues(alpha: 0.12)
                              : theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          departure.minutesRemaining <= 0
                              ? 'Inminente'
                              : 'en ${departure.minutesRemaining} min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: departure.minutesRemaining <= 3
                                ? const Color(0xFFE2001A)
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
