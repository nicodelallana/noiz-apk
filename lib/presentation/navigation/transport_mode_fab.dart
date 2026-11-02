import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/navigation/transport_selector_sheet.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';

/// Legacy transport mode toggle for backward compatibility with existing tests.
enum TransportMode {
  metro('Metro', Icons.directions_subway_rounded, Color(0xFFE2001A)),
  bus('Bus', Icons.directions_bus_rounded, Color(0xFF00843D));

  const TransportMode(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

final transportModeProvider = StateProvider<TransportMode>(
  (ref) => TransportMode.metro,
);

/// Central Floating Action Button that opens the Province-Aware Transport Selector.
/// Displays the active transport mode's icon and operator color.
class TransportModeFab extends ConsumerWidget {
  const TransportModeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeColor = Color(activeOperator.colorHex);
    final icon = _iconForMode(activeOperator.mode);

    return SizedBox(
      width: 62,
      height: 62,
      child: FloatingActionButton(
        heroTag: 'transport_mode_fab',
        onPressed: () => TransportSelectorBottomSheet.show(context),
        backgroundColor: activeColor,
        elevation: 8,
        shape: const CircleBorder(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            icon,
            key: ValueKey(activeOperator.id),
            color: Colors.white,
            size: 28,
          ),
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
