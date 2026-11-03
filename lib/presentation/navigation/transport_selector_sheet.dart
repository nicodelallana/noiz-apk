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

/// Glass sheet that lets the user pick the transport operator, filtered by
/// territory (Bizkaia, Gipuzkoa, Araba).
class TransportSelectorBottomSheet extends ConsumerWidget {
  const TransportSelectorBottomSheet({super.key, this.overMap = false});

  /// Opened over the map tab: on the web the map can't be blurred, so the
  /// sheet uses the denser over-map glass.
  final bool overMap;

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    final location =
        GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration.uri;
    final overMap = location?.path == '/map';
    return showModalBottomSheet<void>(
      context: context,
      // Above the shell, so the sheet covers the floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => TransportSelectorBottomSheet(overMap: overMap),
    );
  }

  void _selectTerritory(
    WidgetRef ref,
    TransitTerritory territory,
    TransitOperator activeOperator,
  ) {
    ref.read(selectedTerritoryProvider.notifier).state = territory;
    // Auto-switch to the territory's first operator if the current one is
    // from another territory.
    if (activeOperator.territory != territory) {
      ref.read(selectedOperatorProvider.notifier).state = switch (territory) {
        TransitTerritory.gipuzkoa => TransitOperator.dbus,
        TransitTerritory.araba => TransitOperator.tuvisa,
        _ => TransitOperator.metro,
      };
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territory = ref.watch(selectedTerritoryProvider);
    final activeOperator = ref.watch(selectedOperatorProvider);

    // List operators for the chosen territory (default to Bizkaia if 'all')
    final effectiveTerritory =
        territory == TransitTerritory.all ? TransitTerritory.bizkaia : territory;
    final operators = TransitOperator.byTerritory(effectiveTerritory);
    final t = AppTypography.textTheme();
    final reduced = Motion.reduced(context);
    final inset = math.max(8.0, MediaQuery.paddingOf(context).bottom);

    return Padding(
      // Floats off the screen edges, iOS-style.
      padding: EdgeInsets.fromLTRB(8, 0, 8, inset),
      child: GlassSurface(
        blur: true,
        kind: overMap ? GlassKind.overMap : GlassKind.regular,
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
                          'Operadores disponibles en ${effectiveTerritory.name}',
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

            _TerritorySegmentedControl(
              selected: effectiveTerritory,
              onChanged: (value) =>
                  _selectTerritory(ref, value, activeOperator),
            ),
            const SizedBox(height: 14),

            // Operator grid
            AnimatedSize(
              duration: reduced ? Duration.zero : Motion.smooth.duration,
              curve: Motion.smooth.curve,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: AnimatedSwitcher(
                  duration: reduced
                      ? Motion.reducedFade
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(effectiveTerritory),
                    child: _OperatorGrid(
                      operators: operators,
                      active: activeOperator,
                      onSelected: (op) {
                        HapticFeedback.lightImpact();
                        ref.read(selectedOperatorProvider.notifier).state = op;
                        Navigator.of(context).pop();
                      },
                    ),
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

/// iOS-style segmented control: a capsule track with a lighter "droplet"
/// (the same one as the tab bar) that springs to the chosen territory. It
/// sits on the glass sheet, so it paints no blur of its own.
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
    final reduced = Motion.reduced(context);
    final m = Motion.snappy;
    final index = _territories.indexOf(selected).clamp(0, 2);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.darkBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(
                  -1 + 2 * index / (_territories.length - 1),
                  0,
                ),
                duration: reduced ? Duration.zero : m.duration,
                curve: m.curve,
                child: FractionallySizedBox(
                  widthFactor: 1 / _territories.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      shadows: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
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
          ],
        ),
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
    final count = TransitOperator.byTerritory(territory).length;
    final countLabel = '$count ${count == 1 ? 'transporte' : 'transportes'}';
    final duration =
        Motion.reduced(context) ? Motion.reducedFade : Motion.snappy.duration;
    void select() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      selected: selected,
      label: '${territory.name}, $countLabel',
      // The excluded subtree takes the detector's tap action with it.
      onTap: select,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: duration,
                style: t.labelLarge!.copyWith(
                  color: selected
                      ? AppColors.darkTextPrimary
                      : AppColors.darkTextSecondary,
                ),
                child: Text(
                  territory.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelMedium!.copyWith(
                  color: selected
                      ? AppColors.darkTextSecondary
                      : AppColors.darkTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-column grid of solid operator tiles; each row takes the height of
/// its taller tile.
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
        // Concentric with the sheet: 32 − 16.
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
                // The operator's colour as a small glowing badge.
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
              style: t.titleSmall!.copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              operator.mode.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall!.copyWith(color: AppColors.darkTextSecondary),
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
