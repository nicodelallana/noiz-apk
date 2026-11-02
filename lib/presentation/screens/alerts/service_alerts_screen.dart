import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/repositories/transit_repository.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/ambient_glow_background.dart';

/// Consolidated Service Alerts & Incidents screen across all Euskadi operators.
class ServiceAlertsScreen extends ConsumerWidget {
  const ServiceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(serviceAlertsProvider);
    final territory = ref.watch(selectedTerritoryProvider);

    return AmbientGlowBackground(
      accentColor: AppColors.delayedAmber,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incidencias',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Avisos del transporte en Euskadi',
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
              tooltip: 'Actualizar avisos',
              onPressed: () => ref.refresh(serviceAlertsProvider),
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
                        selectedColor: AppColors.delayedAmber,
                        side: BorderSide(
                          color: isSel
                              ? AppColors.delayedAmber
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

            // Content List
            Expanded(
              child: alertsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.delayedAmber,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar avisos: $e',
                    style: const TextStyle(color: AppColors.disruptedRed),
                  ),
                ),
                data: (alerts) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      // Summary Counter Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.delayedAmber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.delayedAmber.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                BarikIcons.warning,
                                color: AppColors.delayedAmber,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${alerts.length} avisos activos',
                                    style: const TextStyle(
                                      color: AppColors.darkTextPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Circulación con afecciones y refuerzos',
                                    style: TextStyle(
                                      color: AppColors.darkTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      for (final alert in alerts) ...[
                        _AlertItemCard(alert: alert),
                        const SizedBox(height: 10),
                      ],
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

class _AlertItemCard extends StatelessWidget {
  const _AlertItemCard({required this.alert});

  final ServiceAlert alert;

  @override
  Widget build(BuildContext context) {
    final op = TransitOperator.fromId(alert.operatorId);
    final opColor = Color(op.colorHex);

    final severityColor = switch (alert.severity) {
      'severe' => AppColors.disruptedRed,
      'warning' => AppColors.delayedAmber,
      _ => AppColors.realtimeGreen,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Operator & Line badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: opColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.lineName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                op.name,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (alert.activePeriod != null)
                Text(
                  alert.activePeriod!,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            style: const TextStyle(
              color: AppColors.darkTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.description,
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
