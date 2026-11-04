import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';

/// Floating multi-level transit selector over the map:
/// 1. Modo (Metro, Tren, Tranvía, Autobús, Funicular)
/// 2. Operador (Metro Bilbao, Euskotren, Bizkaibus, etc.)
/// 3. Línea/Ruta (L1, A3115, etc.) con búsqueda y trazado geométrico
class MapTransitSelector extends ConsumerWidget {
  const MapTransitSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(mapSelectedModeProvider);
    final activeOperator = ref.watch(mapSelectedOperatorProvider);
    final activeRoute = ref.watch(mapSelectedRouteProvider);
    final operators = ref.watch(mapFilteredOperatorsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Row: Mode pills (No "Todos" mode: loads instantly per transport type)
        _ModeSelectorRow(
          activeMode: activeMode,
          onSelectMode: (mode) {
            HapticFeedback.selectionClick();
            ref.read(mapSelectedModeProvider.notifier).state = mode;
            ref.read(mapSelectedRouteProvider.notifier).state = null;

            final territory = ref.read(selectedTerritoryProvider);
            final opsForMode = TransitOperator.byTerritory(territory)
                .where((o) => o.mode == mode)
                .toList();

            if (opsForMode.isNotEmpty) {
              if (activeOperator == null ||
                  !opsForMode.contains(activeOperator)) {
                ref.read(mapSelectedOperatorProvider.notifier).state =
                    opsForMode.first;
              }
            } else {
              ref.read(mapSelectedOperatorProvider.notifier).state = null;
            }
          },
        ),

        const SizedBox(height: 8),

        // 2. Row: Operator & Line pill (prominent route visibility)
        if (operators.isNotEmpty ||
            activeOperator != null ||
            activeRoute != null) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Operator chips
                for (final op in operators) ...[
                  _OperatorChip(
                    operator: op,
                    isSelected: activeOperator == op,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (activeOperator != op) {
                        ref.read(mapSelectedOperatorProvider.notifier).state =
                            op;
                      }
                      ref.read(mapSelectedRouteProvider.notifier).state = null;
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Line picker pill: prominently allows viewing routes/shapes
                if (activeOperator != null) ...[
                  _RoutePickerPill(
                    operator: activeOperator,
                    activeRoute: activeRoute,
                    onOpenPicker: () =>
                        _openRoutePicker(context, ref, activeOperator),
                    onClearRoute: () {
                      HapticFeedback.selectionClick();
                      ref.read(mapSelectedRouteProvider.notifier).state = null;
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openRoutePicker(
      BuildContext context, WidgetRef ref, TransitOperator operator) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _RoutePickerSheet(
          operator: operator,
          onSelectRoute: (route) {
            HapticFeedback.selectionClick();
            ref.read(mapSelectedRouteProvider.notifier).state = route;
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

class _ModeSelectorRow extends StatelessWidget {
  const _ModeSelectorRow({
    required this.activeMode,
    required this.onSelectMode,
  });

  final TransitModeType? activeMode;
  final ValueChanged<TransitModeType> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ModeChip(
            label: 'Metro',
            icon: Icons.subway_rounded,
            isSelected: activeMode == TransitModeType.metro,
            onTap: () => onSelectMode(TransitModeType.metro),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: 'Tren',
            icon: Icons.train_rounded,
            isSelected: activeMode == TransitModeType.train,
            onTap: () => onSelectMode(TransitModeType.train),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: 'Tranvía',
            icon: Icons.tram_rounded,
            isSelected: activeMode == TransitModeType.tram,
            onTap: () => onSelectMode(TransitModeType.tram),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: 'Autobús',
            icon: Icons.directions_bus_rounded,
            isSelected: activeMode == TransitModeType.bus,
            onTap: () => onSelectMode(TransitModeType.bus),
          ),
          const SizedBox(width: 8),
          _ModeChip(
            label: 'Funicular',
            icon: Icons.terrain_rounded,
            isSelected: activeMode == TransitModeType.funicular,
            onTap: () => onSelectMode(TransitModeType.funicular),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return GlassButton(
      blur: true,
      kind: GlassKind.overMap,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      tint: isSelected ? AppColors.accent : null,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.darkTextSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: t.labelMedium!.copyWith(
              color: isSelected ? Colors.white : AppColors.darkTextPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({
    required this.operator,
    required this.isSelected,
    required this.onTap,
  });

  final TransitOperator operator;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final opColor = Color(operator.colorHex);
    return GlassButton(
      blur: true,
      kind: GlassKind.overMap,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      tint: isSelected ? opColor.withValues(alpha: 0.35) : null,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: opColor,
              boxShadow: [
                BoxShadow(color: opColor.withValues(alpha: 0.6), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            operator.name,
            style: t.labelMedium!.copyWith(
              color: isSelected ? Colors.white : AppColors.darkTextPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePickerPill extends StatelessWidget {
  const _RoutePickerPill({
    required this.operator,
    required this.activeRoute,
    required this.onOpenPicker,
    required this.onClearRoute,
  });

  final TransitOperator? operator;
  final TransitRoute? activeRoute;
  final VoidCallback onOpenPicker;
  final VoidCallback onClearRoute;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final opColor =
        operator != null ? Color(operator!.colorHex) : AppColors.accent;

    if (activeRoute == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: opColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: opColor.withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: GlassButton(
          blur: true,
          kind: GlassKind.overMap,
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          tint: opColor.withValues(alpha: 0.2),
          onPressed: onOpenPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route_rounded, size: 16, color: opColor),
              const SizedBox(width: 6),
              Text(
                'Ver rutas / líneas ▾',
                style: t.labelMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final colorHex = activeRoute!.colorHex ?? '#025DA9';
    final color = Color(
        int.tryParse('FF${colorHex.replaceFirst('#', '')}', radix: 16) ??
            0xFF025DA9);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: GlassSurface(
        blur: true,
        kind: GlassKind.overMap,
        radius: 999,
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activeRoute!.shortName.isNotEmpty
                    ? activeRoute!.shortName
                    : 'Línea',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                activeRoute!.longName.isNotEmpty
                    ? activeRoute!.longName
                    : activeRoute!.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelMedium!.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: onClearRoute,
              tooltip: 'Quitar ruta del mapa',
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePickerSheet extends ConsumerStatefulWidget {
  const _RoutePickerSheet({
    required this.operator,
    required this.onSelectRoute,
  });

  final TransitOperator operator;
  final ValueChanged<TransitRoute> onSelectRoute;

  @override
  ConsumerState<_RoutePickerSheet> createState() => _RoutePickerSheetState();
}

class _RoutePickerSheetState extends ConsumerState<_RoutePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(mapAvailableRoutesProvider);
    final t = AppTypography.textTheme();
    final opColor = Color(widget.operator.colorHex);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              8, 0, 8, math.max(8.0, MediaQuery.paddingOf(context).bottom)),
          child: GlassSurface(
            blur: true,
            kind: GlassKind.overMap,
            radius: 32,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Grabber
                Container(
                  width: 36,
                  height: 5,
                  decoration: const ShapeDecoration(
                    color: AppColors.darkTextTertiary,
                    shape: StadiumBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: opColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Líneas de ${widget.operator.name}',
                      style: t.titleMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  onChanged: (val) =>
                      setState(() => _search = val.trim().toLowerCase()),
                  style: const TextStyle(
                      color: AppColors.darkTextPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por número o destino...',
                    hintStyle: const TextStyle(
                        color: AppColors.darkTextTertiary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.darkTextSecondary, size: 20),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Routes list
                Expanded(
                  child: routesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    ),
                    error: (err, _) => Center(
                      child: Text(
                        'Error al cargar líneas: $err',
                        style: const TextStyle(color: AppColors.delayedAmber),
                      ),
                    ),
                    data: (routes) {
                      final filtered = routes.where((r) {
                        if (_search.isEmpty) return true;
                        return r.shortName.toLowerCase().contains(_search) ||
                            r.longName.toLowerCase().contains(_search);
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No se encontraron líneas coincidentes.',
                            style: t.bodyMedium!
                                .copyWith(color: AppColors.darkTextSecondary),
                          ),
                        );
                      }

                      return ListView.separated(
                        controller: controller,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0x1AFFFFFF),
                        ),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          final routeColorHex = r.colorHex ?? '#025DA9';
                          final rColor = Color(
                            int.tryParse(
                                    'FF${routeColorHex.replaceFirst('#', '')}',
                                    radix: 16) ??
                                0xFF025DA9,
                          );

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.shortName.isNotEmpty ? r.shortName : 'L',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Text(
                              r.longName.isNotEmpty ? r.longName : r.shortName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyMedium!.copyWith(
                                color: AppColors.darkTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppColors.darkTextTertiary,
                            ),
                            onTap: () => widget.onSelectRoute(r),
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
      },
    );
  }
}
