import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/ambient_glow_background.dart';
import 'package:bizkaia_transit/presentation/widgets/departure_hero_card.dart';

/// "Cerca de ti" Multi-Operator Transit Radar Hub, faithfully reproducing
/// the nearby stops screen observed in Garraio reference videos and web.
class NearbyTransitScreen extends ConsumerStatefulWidget {
  const NearbyTransitScreen({super.key});

  @override
  ConsumerState<NearbyTransitScreen> createState() =>
      _NearbyTransitScreenState();
}

class _NearbyTransitScreenState extends ConsumerState<NearbyTransitScreen> {
  String? _expandedStopId;

  @override
  Widget build(BuildContext context) {
    final nearbyStopsAsync = ref.watch(nearbyStopsProvider);
    final territory = ref.watch(selectedTerritoryProvider);

    return AmbientGlowBackground(
      accentColor: AppColors.opBizkaibus,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cerca de ti',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Todas las paradas a tu alrededor',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(BarikIcons.arrowsClockwise),
              tooltip: 'Actualizar paradas cercanas',
              onPressed: () => ref.refresh(nearbyStopsProvider),
            ),
          ],
        ),
        body: Column(
          children: [
            // Territory Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: TransitTerritory.values.map((t) {
                    final isSel = t == territory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(t.name),
                        labelStyle: TextStyle(
                          color: isSel
                              ? Colors.white
                              : AppColors.darkTextSecondary,
                          fontWeight:
                              isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        backgroundColor: AppColors.darkSurfaceElevated,
                        selectedColor: AppColors.opBizkaibus,
                        side: BorderSide(
                          color: isSel
                              ? AppColors.opBizkaibus
                              : AppColors.darkBorder,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (_) {
                          ref.read(selectedTerritoryProvider.notifier).state =
                              t;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Stops List
            Expanded(
              child: nearbyStopsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.opBizkaibus,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar paradas: $e',
                    style: const TextStyle(color: AppColors.disruptedRed),
                  ),
                ),
                data: (stops) {
                  if (stops.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay paradas registradas en el radio seleccionado.',
                        style: TextStyle(color: AppColors.darkTextSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: stops.length,
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final isExpanded = stop.id == _expandedStopId;
                      final op = TransitOperator.fromId(stop.operatorId);
                      final brandColor = Color(op.colorHex);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isExpanded
                                ? brandColor.withValues(alpha: 0.5)
                                : AppColors.darkBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: brandColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _iconForMode(op.mode),
                                  color: brandColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                stop.name,
                                style: const TextStyle(
                                  color: AppColors.darkTextPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${op.name} · ${stop.territory.toUpperCase()}',
                                style: TextStyle(
                                  color: brandColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                isExpanded
                                    ? BarikIcons.caretUp
                                    : BarikIcons.caretDown,
                                color: AppColors.darkTextSecondary,
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedStopId = isExpanded ? null : stop.id;
                                });
                              },
                            ),

                            if (isExpanded)
                              _StopDeparturesExpandedView(
                                stop: stop,
                                operator: op,
                              ),
                          ],
                        ),
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

class _StopDeparturesExpandedView extends ConsumerWidget {
  const _StopDeparturesExpandedView({
    required this.stop,
    required this.operator,
  });

  final Stop stop;
  final TransitOperator operator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(transitRepositoryProvider);

    return FutureBuilder<List<Departure>>(
      future: repo.getDepartures(stopId: stop.id, operatorId: operator.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final departures = snapshot.data ?? [];
        if (departures.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No hay salidas programadas en los próximos minutos.',
              style: TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 13,
              ),
            ),
          );
        }

        final next = departures.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 8),
              DepartureHeroCard(
                departure: next,
                operator: operator,
                originName: stop.name,
              ),
            ],
          ),
        );
      },
    );
  }
}
