import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Clean top selector bar over the map:
/// Shows active Province, Operator and Route, and opens the Modal Bottom Sheet on tap.
class MapTransitSelector extends ConsumerWidget {
  const MapTransitSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territory = ref.watch(selectedTerritoryProvider);
    final TransitOperator activeOperator =
        ref.watch(mapSelectedOperatorProvider) ??
            ref.watch(selectedOperatorProvider);
    final activeRoute = ref.watch(mapSelectedRouteProvider);
    final opColor = Color(activeOperator.colorHex);
    final t = AppTypography.textTheme();

    final lineLabel = activeRoute != null
        ? (activeRoute.shortName.isNotEmpty
            ? activeRoute.shortName
            : activeRoute.longName)
        : 'Todas las líneas';

    return GestureDetector(
      onTap: () => showTransitSelectionSheet(context),
      child: GlassSurface(
        blur: true,
        kind: GlassKind.overMap,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // 1. Territory badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: ShapeDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: continuousShape(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    territory.name,
                    style: t.labelMedium!.copyWith(
                      color: AppColors.darkTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 2. Operator dot & name
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: opColor,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activeOperator.name,
                style: t.labelLarge!.copyWith(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 16,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(width: 8),

            // 3. Line badge / label with chevron spanning the full remaining width
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lineLabel,
                      style: t.labelMedium!.copyWith(
                        color: activeRoute != null
                            ? opColor
                            : AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.darkTextSecondary,
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

/// Helper to trigger the modal bottom sheet from anywhere
void showTransitSelectionSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => const TransitSelectionModalSheet(),
  );
}

/// Complete Modal Bottom Sheet for selecting:
/// 1. Provincia / Territorio (Bizkaia, Gipuzkoa, Álava)
/// 2. Tipo de Transporte & Operador (Metro Bilbao, Bizkaibus, Bilbobus, etc.)
/// 3. Línea / Recorrido (Metro: L1, L2, L3; Bus: código + recorrido)
class TransitSelectionModalSheet extends ConsumerStatefulWidget {
  const TransitSelectionModalSheet({super.key});

  @override
  ConsumerState<TransitSelectionModalSheet> createState() =>
      _TransitSelectionModalSheetState();
}

class _TransitSelectionModalSheetState
    extends ConsumerState<TransitSelectionModalSheet> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final territory = ref.watch(selectedTerritoryProvider);
    final TransitOperator activeOperator =
        ref.watch(mapSelectedOperatorProvider) ??
            ref.watch(selectedOperatorProvider);
    final activeMode = ref.watch(mapSelectedModeProvider) ?? activeOperator.mode;
    final activeRoute = ref.watch(mapSelectedRouteProvider);
    final routesAsync = ref.watch(mapAvailableRoutesProvider);
    final operatorsForMode = ref.watch(mapFilteredOperatorsProvider);

    final t = AppTypography.textTheme();
    final opColor = Color(activeOperator.colorHex);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.40,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            8,
            math.max(8.0, MediaQuery.paddingOf(context).bottom),
          ),
          child: GlassSurface(
            blur: true,
            kind: GlassKind.overMap,
            radius: 32,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ListView(
              controller: scrollController,
              children: [
                // ── Grabber ────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: const ShapeDecoration(
                      color: AppColors.darkTextTertiary,
                      shape: StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  'Elige transporte y línea',
                  style: t.headlineSmall!.copyWith(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Selecciona provincia, operador y trazado en el mapa',
                  style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: 16),

                // ── 1. Provincia / Territorio ──────────────────────────────
                Text(
                  'PROVINCIA / TERRITORIO',
                  style: t.labelSmall!.copyWith(
                    color: AppColors.darkTextTertiary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TerritoryTab(
                      label: 'Bizkaia',
                      isSelected: territory == TransitTerritory.bizkaia,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedTerritoryProvider.notifier).state =
                            TransitTerritory.bizkaia;
                        final defOp = TransitOperator.metro;
                        ref.read(mapSelectedOperatorProvider.notifier).state = defOp;
                        ref.read(mapSelectedModeProvider.notifier).state = defOp.mode;
                        ref.read(mapSelectedRouteProvider.notifier).state = null;
                        switchOperator(ref, defOp);
                      },
                    ),
                    const SizedBox(width: 8),
                    _TerritoryTab(
                      label: 'Gipuzkoa',
                      isSelected: territory == TransitTerritory.gipuzkoa,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedTerritoryProvider.notifier).state =
                            TransitTerritory.gipuzkoa;
                        final defOp = TransitOperator.dbus;
                        ref.read(mapSelectedOperatorProvider.notifier).state = defOp;
                        ref.read(mapSelectedModeProvider.notifier).state = defOp.mode;
                        ref.read(mapSelectedRouteProvider.notifier).state = null;
                        switchOperator(ref, defOp);
                      },
                    ),
                    const SizedBox(width: 8),
                    _TerritoryTab(
                      label: 'Álava',
                      isSelected: territory == TransitTerritory.araba,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedTerritoryProvider.notifier).state =
                            TransitTerritory.araba;
                        final defOp = TransitOperator.tuvisa;
                        ref.read(mapSelectedOperatorProvider.notifier).state = defOp;
                        ref.read(mapSelectedModeProvider.notifier).state = defOp.mode;
                        ref.read(mapSelectedRouteProvider.notifier).state = null;
                        switchOperator(ref, defOp);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── 2. Tipo de Transporte ──────────────────────────────────
                Text(
                  'TIPO DE TRANSPORTE',
                  style: t.labelSmall!.copyWith(
                    color: AppColors.darkTextTertiary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _ModeChip(
                        label: 'Metro',
                        icon: BarikIcons.subway,
                        isSelected: activeMode == TransitModeType.metro,
                        onTap: () => _onSelectMode(TransitModeType.metro),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: 'Tren',
                        icon: BarikIcons.train,
                        isSelected: activeMode == TransitModeType.train,
                        onTap: () => _onSelectMode(TransitModeType.train),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: 'Tranvía',
                        icon: BarikIcons.tram,
                        isSelected: activeMode == TransitModeType.tram,
                        onTap: () => _onSelectMode(TransitModeType.tram),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: 'Autobús',
                        icon: BarikIcons.bus,
                        isSelected: activeMode == TransitModeType.bus,
                        onTap: () => _onSelectMode(TransitModeType.bus),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: 'Funicular',
                        icon: BarikIcons.cableCar,
                        isSelected: activeMode == TransitModeType.funicular,
                        onTap: () => _onSelectMode(TransitModeType.funicular),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Operadores para el modo seleccionado ────────────────────
                if (operatorsForMode.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final op in operatorsForMode)
                        _OperatorBadgeChip(
                          operator: op,
                          isSelected: activeOperator == op,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(mapSelectedOperatorProvider.notifier).state = op;
                            ref.read(mapSelectedRouteProvider.notifier).state = null;
                            switchOperator(ref, op);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 3. Selector de Líneas ──────────────────────────────────
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
                      'LÍNEAS DE ${activeOperator.name.toUpperCase()}',
                      style: t.labelSmall!.copyWith(
                        color: AppColors.darkTextTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Option: "Todas las líneas"
                _LineOptionTile(
                  code: 'TODAS',
                  title: 'Ver red completa en el mapa',
                  color: opColor,
                  isSelected: activeRoute == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(mapSelectedRouteProvider.notifier).state = null;
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),

                // Bus Search Bar if there are many routes
                if (activeOperator.mode == TransitModeType.bus) ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _search = val.trim().toLowerCase()),
                    style: const TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código o destino (ej: A3151)...',
                      hintStyle: const TextStyle(
                        color: AppColors.darkTextTertiary,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        BarikIcons.magnifyingGlass,
                        color: AppColors.darkTextSecondary,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Route Items
                routesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error al cargar líneas: $e',
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
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No se encontraron líneas',
                            style: t.bodySmall!
                                .copyWith(color: AppColors.darkTextTertiary),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final route in filtered) ...[
                          _LineOptionTile(
                            code: route.shortName.isNotEmpty
                                ? route.shortName
                                : activeOperator.name,
                            title: route.longName,
                            color: route.colorHex != null &&
                                    route.colorHex!.isNotEmpty
                                ? _parseHexColor(route.colorHex!, opColor)
                                : opColor,
                            isSelected: activeRoute?.id == route.id,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(mapSelectedRouteProvider.notifier).state =
                                  route;
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSelectMode(TransitModeType mode) {
    HapticFeedback.selectionClick();
    ref.read(mapSelectedModeProvider.notifier).state = mode;
    ref.read(mapSelectedRouteProvider.notifier).state = null;

    final territory = ref.read(selectedTerritoryProvider);
    final opsForMode = TransitOperator.byTerritory(territory)
        .where((o) => o.mode == mode)
        .toList();

    if (opsForMode.isNotEmpty) {
      final firstOp = opsForMode.first;
      ref.read(mapSelectedOperatorProvider.notifier).state = firstOp;
      switchOperator(ref, firstOp);
    }
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}

class _TerritoryTab extends StatelessWidget {
  const _TerritoryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: ShapeDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            shape: continuousShape(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.4 : 0.8,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          shape: continuousShape(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.accent : AppColors.darkTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorBadgeChip extends StatelessWidget {
  const _OperatorBadgeChip({
    required this.operator,
    required this.isSelected,
    required this.onTap,
  });

  final TransitOperator operator;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(operator.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: ShapeDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          shape: continuousShape(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              operator.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkTextPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineOptionTile extends StatelessWidget {
  const _LineOptionTile({
    required this.code,
    required this.title,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String title;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          shape: continuousShape(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            // Line code badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: ShapeDecoration(
                color: color,
                shape: continuousShape(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Route journey description
            Expanded(
              child: Text(
                title,
                style: t.bodyMedium!.copyWith(
                  color: isSelected ? Colors.white : AppColors.darkTextPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
