import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/navigation/transport_selector_sheet.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

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

/// Glass circle beside the tab bar that opens the transport selector. Tinted
/// with the active operator's colour: it is the screen's one primary action.
class TransportModeFab extends ConsumerWidget {
  const TransportModeFab({
    super.key,
    this.compact = false,
    this.overMap = false,
  });

  /// Matches the tab bar's compact height while the page scrolls.
  final bool compact;

  /// Sits over the map (Mapa tab): see [GlassKind.overMap].
  final bool overMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeColor = Color(activeOperator.colorHex);
    final icon = _iconForMode(activeOperator.mode);
    final size = compact ? 50.0 : 62.0;
    final reduced = Motion.reduced(context);

    return AnimatedContainer(
      duration: reduced ? Motion.reducedFade : Motion.snappy.duration,
      curve: reduced ? Curves.linear : Motion.snappy.curve,
      width: size,
      height: size,
      child: GlassButton(
        blur: true,
        onPressed: () => TransportSelectorBottomSheet.show(context),
        semanticLabel: 'Cambiar transporte: ${activeOperator.name}',
        kind: overMap ? GlassKind.overMap : GlassKind.regular,
        tint: activeColor,
        padding: EdgeInsets.zero,
        child: Center(
          child: AnimatedSwitcher(
            duration: reduced ? Motion.reducedFade : Motion.bouncy.duration,
            switchInCurve: reduced ? Curves.linear : Motion.bouncy.curve,
            transitionBuilder: (child, animation) => reduced
                ? FadeTransition(opacity: animation, child: child)
                : ScaleTransition(scale: animation, child: child),
            child: Icon(
              icon,
              key: ValueKey(activeOperator.id),
              color: Colors.white,
              size: compact ? 22 : 26,
            ),
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
