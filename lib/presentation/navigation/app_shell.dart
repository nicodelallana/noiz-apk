import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/constants/transit_constants.dart';
import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_theme.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';
import 'package:bizkaia_transit/presentation/navigation/transport_mode_fab.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/aurora_background.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// App shell: the aurora backdrop behind every tab, and a floating
/// liquid-glass capsule tab bar with the transport-mode button beside it
/// (iOS 26 keeps actions out of the tab bar). The bar compacts while the
/// page scrolls down and expands again on scroll up.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  /// The routed page content.
  final Widget child;

  /// Active navigation tab index (0-3).
  final int currentIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _compact = false;

  void _onTabSelected(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    final path = switch (index) {
      0 => '/',
      1 => '/map',
      2 => '/alerts',
      3 => '/settings',
      _ => '/',
    };
    context.go(path);
  }

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth > 1) return false;
    final delta = n.scrollDelta ?? 0;
    final pastTop = n.metrics.pixels > 32;
    final compact =
        (pastTop && delta > 0) || (_compact && pastTop && delta >= -4);
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex && _compact) {
      _compact = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOperator = ref.watch(selectedOperatorProvider);
    final activeTrip = ref.watch(activeLiveTripProvider);
    final nearbyAlerts = ref.watch(rankedServiceAlertsProvider).valueOrNull
            ?.where((r) =>
                r.distanceKm != null &&
                r.distanceKm! < TransitConstants.nearbyAlertsRadiusKm)
            .length ??
        0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barBottom = bottomInset + 12;

    return Theme(
      data: AppTheme.themeFor(accentColor: AppColors.accent),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: AuroraBackground(
          accent: Color(activeOperator.colorHex),
          // Hidden behind the full-screen map: no need to keep drifting.
          animate: widget.currentIndex != 1,
          child: BackdropGroup(
            child: Stack(
              children: [
                Positioned.fill(
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: _onScroll,
                    child: widget.child,
                  ),
                ),
                // Scroll-edge fade so content reads under the floating bar.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: barBottom + 90,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0006080C), Color(0xB306080C)],
                        ),
                      ),
                    ),
                  ),
                ),
                if (activeTrip != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: barBottom + 74,
                    child: _ActiveTripMiniBanner(trip: activeTrip),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: barBottom,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _GlassTabBar(
                          currentIndex: widget.currentIndex,
                          compact: _compact,
                          overMap: widget.currentIndex == 1,
                          alertsBadge: nearbyAlerts,
                          onSelected: _onTabSelected,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TransportModeFab(
                        compact: _compact,
                        overMap: widget.currentIndex == 1,
                      ),
                    ],
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

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = [
  _TabSpec('Inicio', Icons.access_time_rounded, Icons.access_time_filled_rounded),
  _TabSpec('Mapa', Icons.map_outlined, Icons.map_rounded),
  _TabSpec('Alertas', Icons.notifications_none_rounded, Icons.notifications_rounded),
  _TabSpec('Cuenta', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Capsule glass bar with a lighter glass "droplet" that springs between tabs.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({
    required this.currentIndex,
    required this.compact,
    required this.overMap,
    required this.alertsBadge,
    required this.onSelected,
  });

  final int currentIndex;
  final bool compact;
  final bool overMap;
  final int alertsBadge;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final m = Motion.snappy;
    final height = compact ? 50.0 : 62.0;
    final index = currentIndex.clamp(0, _tabs.length - 1);

    return AnimatedContainer(
      duration: reduced ? Motion.reducedFade : m.duration,
      curve: reduced ? Curves.linear : m.curve,
      height: height,
      child: GlassSurface(
        kind: overMap ? GlassKind.overMap : GlassKind.regular,
        radius: 999,
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(-1 + 2 * index / (_tabs.length - 1), 0),
              duration: reduced ? Duration.zero : m.duration,
              curve: m.curve,
              child: FractionallySizedBox(
                widthFactor: 1 / _tabs.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      spec: _tabs[i],
                      selected: i == index,
                      compact: compact,
                      badge: i == 2 ? alertsBadge : 0,
                      onTap: () => onSelected(i),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.compact,
    required this.badge,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final bool compact;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary;
    final reduced = Motion.reduced(context);
    final m = Motion.snappy;

    return Semantics(
      selected: selected,
      button: true,
      label: spec.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.disruptedRed,
              textStyle: AppTypography.time.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              child: AnimatedScale(
                scale: selected && !reduced ? 1.08 : 1,
                duration: m.duration,
                curve: m.curve,
                child: Icon(
                  selected ? spec.selectedIcon : spec.icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
            AnimatedSize(
              duration: reduced ? Duration.zero : m.duration,
              curve: m.curve,
              child: compact
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: AppTypography.textTheme().labelSmall!.copyWith(
                              color: color,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
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

/// Glass banner shown while a departure is being followed.
class _ActiveTripMiniBanner extends ConsumerWidget {
  const _ActiveTripMiniBanner({required this.trip});

  final LiveTripState trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineColor = Color(
      int.tryParse(trip.lineColor.replaceAll('#', '0xFF')) ?? 0xFFE2001A,
    );
    final ended = trip.status == LiveTripStatus.ended;

    return GlassButton(
      onPressed: () => context.go('/'),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: ShapeDecoration(
              color: lineColor,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              trip.lineName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hacia ${trip.destination}',
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ended
                      ? 'Viaje finalizado'
                      : '${trip.minutesRemaining} min · '
                          '${trip.isRealtime ? 'En directo' : 'Según horario'}',
                  style: AppTypography.time.copyWith(
                    color: ended
                        ? AppColors.realtimeGreen
                        : AppColors.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              BarikIcons.stopCircle,
              color: AppColors.darkTextSecondary,
              size: 22,
            ),
            tooltip: 'Detener seguimiento',
            onPressed: () {
              ref.read(activeLiveTripProvider.notifier).endTrip();
            },
          ),
        ],
      ),
    );
  }
}
