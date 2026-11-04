import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Redesigned two-level transport selector bottom sheet:
/// - Primary selector: Transport categories (Metro, Autobús, Tren, Tranvía, Funicular).
/// - Secondary selector: Official operators/services belonging to the selected category.
class TransportSelectorBottomSheet extends ConsumerStatefulWidget {
  const TransportSelectorBottomSheet({super.key, this.overMap = false});

  final bool overMap;

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    final location =
        GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration.uri;
    final overMap = location?.path == '/map';
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => TransportSelectorBottomSheet(overMap: overMap),
    );
  }

  @override
  ConsumerState<TransportSelectorBottomSheet> createState() =>
      _TransportSelectorBottomSheetState();
}

class _TransportSelectorBottomSheetState
    extends ConsumerState<TransportSelectorBottomSheet> {
  TransitModeType? _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = ref.read(selectedOperatorProvider).mode;
  }

  void _onCategorySelected(TransitModeType mode) {
    HapticFeedback.selectionClick();
    setState(() => _selectedMode = mode);
  }

  void _onTerritorySelected(TransitTerritory territory) {
    ref.read(selectedTerritoryProvider.notifier).state = territory;
    final currentMode = _selectedMode ?? TransitModeType.metro;
    final availableInMode = TransitOperator.values
        .where((op) => op.territory == territory && op.mode == currentMode)
        .toList();

    // If the currently selected category has no operators in this territory,
    // switch category to one that has operators.
    if (availableInMode.isEmpty) {
      final anyOp = TransitOperator.byTerritory(territory).firstOrNull;
      if (anyOp != null) {
        setState(() => _selectedMode = anyOp.mode);
      }
    }
  }

  Future<void> _selectOperator(TransitOperator op) async {
    HapticFeedback.lightImpact();
    await switchOperator(ref, op);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final territory = ref.watch(selectedTerritoryProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);

    final effectiveTerritory = territory == TransitTerritory.all
        ? TransitTerritory.bizkaia
        : territory;

    final currentMode = _selectedMode ?? activeOperator.mode;
    final operatorsInMode = TransitOperator.values
        .where((op) =>
            op.territory == effectiveTerritory && op.mode == currentMode)
        .toList();

    final t = AppTypography.textTheme();
    final reduced = Motion.reduced(context);
    final inset = math.max(8.0, MediaQuery.paddingOf(context).bottom);

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, inset),
      child: GlassSurface(
        blur: true,
        kind: widget.overMap ? GlassKind.overMap : GlassKind.regular,
        radius: 32,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Elige tu transporte',
                            style: t.titleLarge!.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selecciona tipo de transporte y operador',
                          style: t.bodySmall!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActiveOperatorChip(operator: activeOperator),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Primary Selector: Categories ───────────────────────────────
            Text(
              'TIPO DE TRANSPORTE',
              style: t.labelSmall!.copyWith(
                color: AppColors.darkTextTertiary,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _ModeCategorySelector(
              selectedMode: currentMode,
              territory: effectiveTerritory,
              onSelected: _onCategorySelected,
            ),
            const SizedBox(height: 14),

            // Territory filter
            _TerritorySegmentedControl(
              selected: effectiveTerritory,
              onChanged: _onTerritorySelected,
            ),
            const SizedBox(height: 16),

            // ── Secondary Selector: Operators in Category ──────────────────
            Row(
              children: [
                Text(
                  'OPERADORES (${currentMode.label.toUpperCase()})',
                  style: t.labelSmall!.copyWith(
                    color: AppColors.darkTextTertiary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${operatorsInMode.length} ${operatorsInMode.length == 1 ? 'disponible' : 'disponibles'}',
                  style: t.labelSmall!.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: AnimatedSwitcher(
                duration: reduced
                    ? Motion.reducedFade
                    : const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: operatorsInMode.isEmpty
                    ? Padding(
                        key: const ValueKey('empty_ops'),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No hay servicios de ${currentMode.label.toLowerCase()} en ${effectiveTerritory.name}',
                            style: t.bodyMedium!.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        key: ValueKey('${effectiveTerritory.id}_${currentMode.id}'),
                        child: _OperatorGrid(
                          operators: operatorsInMode,
                          active: activeOperator,
                          onSelected: _selectOperator,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary category selector bar with clear visual states (selected, unselected, disabled).
class _ModeCategorySelector extends StatelessWidget {
  const _ModeCategorySelector({
    required this.selectedMode,
    required this.territory,
    required this.onSelected,
  });

  final TransitModeType selectedMode;
  final TransitTerritory territory;
  final ValueChanged<TransitModeType> onSelected;

  static const _modes = [
    TransitModeType.metro,
    TransitModeType.bus,
    TransitModeType.train,
    TransitModeType.tram,
    TransitModeType.funicular,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final mode in _modes) ...[
            _ModeChip(
              mode: mode,
              selected: mode == selectedMode,
              hasOperators: TransitOperator.values
                  .any((op) => op.territory == territory && op.mode == mode),
              onTap: () => onSelected(mode),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.hasOperators,
    required this.onTap,
  });

  final TransitModeType mode;
  final bool selected;
  final bool hasOperators;
  final VoidCallback onTap;

  static IconData _iconFor(TransitModeType mode) => switch (mode) {
        TransitModeType.metro => BarikIcons.subway,
        TransitModeType.train => BarikIcons.train,
        TransitModeType.tram => BarikIcons.tram,
        TransitModeType.bus => BarikIcons.bus,
        TransitModeType.funicular => BarikIcons.cableCar,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final enabled = hasOperators;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: mode.label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: ShapeDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              shape: continuousShape(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.10),
                  width: selected ? 1.5 : 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconFor(mode),
                  size: 18,
                  color: selected ? AppColors.accent : AppColors.darkTextSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  mode.label,
                  style: t.labelLarge!.copyWith(
                    color: selected
                        ? AppColors.darkTextPrimary
                        : AppColors.darkTextSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The operator in use: a dot in its colour and its name.
class _ActiveOperatorChip extends StatelessWidget {
  const _ActiveOperatorChip({required this.operator});

  final TransitOperator operator;

  @override
  Widget build(BuildContext context) {
    final color = Color(operator.colorHex);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 6, 11, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  operator.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme().labelMedium!.copyWith(
                        color: AppColors.darkTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style segmented control: a capsule track for territory.
class _TerritorySegmentedControl extends StatelessWidget {
  const _TerritorySegmentedControl({
    required this.selected,
    required this.onChanged,
  });

  static const _territories = [
    TransitTerritory.bizkaia,
    TransitTerritory.gipuzkoa,
    TransitTerritory.araba,
  ];

  final TransitTerritory selected;
  final ValueChanged<TransitTerritory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final territory in _territories)
            Expanded(
              child: _Segment(
                territory: territory,
                selected: territory == selected,
                onTap: () => onChanged(territory),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.territory,
    required this.selected,
    required this.onTap,
  });

  final TransitTerritory territory;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    void select() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: territory.name,
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: ShapeDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Center(
            child: Text(
              territory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelLarge!.copyWith(
                color: selected
                    ? AppColors.darkTextPrimary
                    : AppColors.darkTextSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of solid operator tiles.
class _OperatorGrid extends StatelessWidget {
  const _OperatorGrid({
    required this.operators,
    required this.active,
    required this.onSelected,
  });

  final List<TransitOperator> operators;
  final TransitOperator active;
  final ValueChanged<TransitOperator> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget tile(TransitOperator op) => _OperatorTile(
          operator: op,
          selected: op == active,
          onTap: () => onSelected(op),
        );

    return Column(
      children: [
        for (var i = 0; i < operators.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tile(operators[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < operators.length
                        ? tile(operators[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OperatorTile extends StatelessWidget {
  const _OperatorTile({
    required this.operator,
    required this.selected,
    required this.onTap,
  });

  final TransitOperator operator;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();
    final color = Color(operator.colorHex);
    final reduced = Motion.reduced(context);

    return Semantics(
      button: true,
      selected: selected,
      child: SurfaceCard(
        radius: 16,
        padding: const EdgeInsets.all(12),
        accent: selected ? AppColors.accent : null,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: ShapeDecoration(
                    color: color,
                    shape: continuousShape(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    shadows: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: -3,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _iconForMode(operator.mode),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const Spacer(),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: reduced ? Duration.zero : Motion.bouncy.duration,
                  curve: Motion.bouncy.curve,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              operator.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleSmall!.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (operator.hasRealtime) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.realtimeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'En directo',
                    style: t.labelSmall!.copyWith(
                      color: AppColors.realtimeGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Text(
                    'Horarios oficiales',
                    style: t.labelSmall!.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForMode(TransitModeType mode) {
    return switch (mode) {
      TransitModeType.metro => BarikIcons.subway,
      TransitModeType.train => BarikIcons.train,
      TransitModeType.tram => BarikIcons.tram,
      TransitModeType.bus => BarikIcons.bus,
      TransitModeType.funicular => BarikIcons.cableCar,
    };
  }
}
