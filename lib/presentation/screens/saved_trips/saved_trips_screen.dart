import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/models/saved_trip_models.dart';
import '../../providers/saved_trips_providers.dart';
import '../../widgets/animations/empty_transit_view.dart';
import '../../widgets/glass/content.dart';
import '../../widgets/glass/glass_surface.dart';
import 'save_trip_dialog.dart';

final _text = AppTypography.textTheme();

/// "Mis viajes" screen displaying user bookmarked commutes with next departures.
class SavedTripsScreen extends ConsumerWidget {
  const SavedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(savedTripsStreamProvider);

    final List<Widget> body = tripsAsync.when(
      loading: () => const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
          child: Text(
            'Error al cargar viajes: $e',
            textAlign: TextAlign.center,
            style: _text.bodyMedium!.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
      data: (trips) {
        if (trips.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyTransitView(
                title: 'No tienes viajes guardados',
                message:
                    'Guarda tus trayectos habituales (como Bagatza ⇄ Kabiezes) para ver las próximas salidas de un vistazo.',
              ),
            ),
          ];
        }
        return [
          for (var i = 0; i < trips.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SavedTripCard(trip: trips[i]),
            ),
          ],
        ];
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              // Top clears the floating actions; bottom the tab bar.
              padding: const EdgeInsets.only(top: 60, bottom: 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Mis viajes',
                      style: _text.displayMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ),
                ...body,
              ],
            ),
            // Navigation layer: floating glass actions.
            Positioned(
              top: 8,
              right: 16,
              child: Row(
                children: [
                  GlassButton(
                    semanticLabel: 'Sincronizar viajes',
                    padding: const EdgeInsets.all(10),
                    onPressed: () => ref
                        .read(savedTripsControllerProvider.notifier)
                        .syncRemote(),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    tint: AppColors.accent,
                    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const SaveTripDialog(),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded,
                            size: 20, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Guardar viaje',
                          style: _text.labelLarge!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final secondary = _text.bodySmall!.copyWith(
      color: AppColors.darkTextSecondary,
    );

    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: ShapeDecoration(
          color: AppColors.disruptedRed,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Text(
              'Eliminar',
              style: _text.labelLarge!.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        ref.read(savedTripsControllerProvider.notifier).deleteTrip(trip.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viaje "${trip.name}" eliminado.')),
        );
      },
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: operator badge, name and widget toggle
            Row(
              children: [
                LineBadge(
                  label: trip.operator.name,
                  color: Color(trip.operator.colorHex),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trip.name,
                    style: _text.titleMedium!.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    trip.widgetEnabled
                        ? Icons.widgets_rounded
                        : Icons.widgets_outlined,
                    color: trip.widgetEnabled
                        ? AppColors.accent
                        : AppColors.darkTextTertiary,
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

            const SizedBox(height: 4),

            // Route endpoints
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.trip_origin_rounded,
                    size: 14,
                    color: AppColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trip.originStopName,
                      overflow: TextOverflow.ellipsis,
                      style: _text.bodyMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppColors.darkTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      trip.destStopName,
                      overflow: TextOverflow.ellipsis,
                      style: _text.bodyMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 10, 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.darkBorder,
              ),
            ),

            // Next departure preview
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: nextDepartureAsync.when(
                loading: () => Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text('Calculando próxima salida...', style: secondary),
                  ],
                ),
                error: (_, __) =>
                    Text('Próxima salida no disponible', style: secondary),
                data: (departure) {
                  if (departure == null) {
                    return Text(
                      'No hay salidas programadas en las próximas horas',
                      style: secondary,
                    );
                  }

                  final minutes = departure.minutesRemaining;
                  return Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salida a las ${departure.scheduledTimeFormatted}',
                              style: AppTypography.time.copyWith(
                                fontSize: 14,
                                color: AppColors.darkTextPrimary,
                              ),
                            ),
                            DepartureStatus(
                              isRealtime: departure.isRealtime,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          minutes <= 0 ? 'Inminente' : 'en $minutes min',
                          style: AppTypography.time.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
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
