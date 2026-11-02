import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';

/// Modal Bottom Sheet that lets the user select transport operator
/// filtered dynamically by the chosen territory/province (Bizkaia, Gipuzkoa, Araba).
class TransportSelectorBottomSheet extends ConsumerWidget {
  const TransportSelectorBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransportSelectorBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territory = ref.watch(selectedTerritoryProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeColor = Color(activeOperator.colorHex);

    // List operators for the chosen territory (default to Bizkaia if 'all')
    final effectiveTerritory =
        territory == TransitTerritory.all ? TransitTerritory.bizkaia : territory;
    final operators = TransitOperator.byTerritory(effectiveTerritory);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorderStrong, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elige tu transporte',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkTextPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Operadores disponibles en ${effectiveTerritory.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.darkTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    activeOperator.name,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Province / Territory Selector Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  _TerritoryTab(
                    title: 'Bizkaia',
                    count: 7,
                    isSelected: effectiveTerritory == TransitTerritory.bizkaia,
                    onTap: () {
                      ref.read(selectedTerritoryProvider.notifier).state =
                          TransitTerritory.bizkaia;
                      // Auto-switch to first operator in Bizkaia if current is from other territory
                      if (activeOperator.territory != TransitTerritory.bizkaia) {
                        ref.read(selectedOperatorProvider.notifier).state =
                            TransitOperator.metro;
                      }
                    },
                  ),
                  _TerritoryTab(
                    title: 'Gipuzkoa',
                    count: 4,
                    isSelected: effectiveTerritory == TransitTerritory.gipuzkoa,
                    onTap: () {
                      ref.read(selectedTerritoryProvider.notifier).state =
                          TransitTerritory.gipuzkoa;
                      if (activeOperator.territory != TransitTerritory.gipuzkoa) {
                        ref.read(selectedOperatorProvider.notifier).state =
                            TransitOperator.dbus;
                      }
                    },
                  ),
                  _TerritoryTab(
                    title: 'Araba',
                    count: 4,
                    isSelected: effectiveTerritory == TransitTerritory.araba,
                    onTap: () {
                      ref.read(selectedTerritoryProvider.notifier).state =
                          TransitTerritory.araba;
                      if (activeOperator.territory != TransitTerritory.araba) {
                        ref.read(selectedOperatorProvider.notifier).state =
                            TransitOperator.tuvisa;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Operator List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.48,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: operators.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final op = operators[index];
                  final isSelected = op == activeOperator;
                  final opColor = Color(op.colorHex);

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(selectedOperatorProvider.notifier).state = op;
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? opColor.withValues(alpha: 0.15)
                            : AppColors.darkSurfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? opColor : AppColors.darkBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icon Avatar
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: opColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _iconForMode(op.mode),
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name and details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  op.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppColors.darkTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      op.mode.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.darkTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (op.hasRealtime)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.realtimeGreen
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'En directo',
                                          style: TextStyle(
                                            color: AppColors.realtimeGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkBorderStrong,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Según horario',
                                          style: TextStyle(
                                            color: AppColors.darkTextSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Selection indicator
                          if (isSelected)
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: opColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
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

class _TerritoryTab extends StatelessWidget {
  const _TerritoryTab({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: AppColors.darkBorderStrong)
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.darkTextPrimary
                      : AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count transportes',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.realtimeGreen
                      : AppColors.darkTextSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
