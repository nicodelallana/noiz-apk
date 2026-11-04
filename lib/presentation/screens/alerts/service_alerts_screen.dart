import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/constants/transit_constants.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/stop/stop_departures_screen.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// Operators offered as filters for the "Toda la red" section.
const _filterOperators = [
  TransitOperator.metro,
  TransitOperator.bizkaibus,
  TransitOperator.euskotren,
  TransitOperator.renfe,
];

String _filterLabel(TransitOperator? op) => switch (op) {
      null => 'Todas',
      TransitOperator.renfe => 'Cercanías',
      _ => op.name,
    };

/// Operator filter for the "Toda la red" section; null shows every operator.
final _alertsOperatorFilterProvider =
    StateProvider.autoDispose<TransitOperator?>((ref) => null);

/// Cards built this soon after the list (re)appears play the staggered
/// entrance; cards built later by scrolling just appear.
const _entranceWindow = Duration(milliseconds: 500);

/// Service alerts ranked by distance: alerts within 3 km of the user first,
/// then the rest of the network with operator filters. Tapping an alert opens
/// the departures of its closest affected stop.
class ServiceAlertsScreen extends ConsumerStatefulWidget {
  const ServiceAlertsScreen({super.key});

  @override
  ConsumerState<ServiceAlertsScreen> createState() =>
      _ServiceAlertsScreenState();
}

class _ServiceAlertsScreenState extends ConsumerState<ServiceAlertsScreen> {
  DateTime? _entranceFrom;

  bool get _entranceOpen =>
      _entranceFrom != null &&
      DateTime.now().difference(_entranceFrom!) < _entranceWindow;

  void _selectFilter(TransitOperator? op) {
    _entranceFrom = DateTime.now();
    ref.read(_alertsOperatorFilterProvider.notifier).state = op;
  }

  @override
  Widget build(BuildContext context) {
    final ranked = ref.watch(rankedServiceAlertsProvider);
    final filter = ref.watch(_alertsOperatorFilterProvider);
    final hasRealFix = ref.watch(userLocationProvider) != null;
    final reduced = Motion.reduced(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.darkSurfaceElevated,
          onRefresh: () async {
            ref.invalidate(serviceAlertsProvider);
            await ref.read(rankedServiceAlertsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: _LargeTitle('Incidencias')),
              const SliverToBoxAdapter(child: _SourceNotice()),
              ...ranked.when(
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 120),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    ),
                  ),
                ],
                error: (_, __) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Center(
                        child: Text(
                          'No se han podido cargar los avisos.',
                          style: _text.bodyMedium!.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                data: (all) {
                  _entranceFrom ??= DateTime.now();
                  final animate = !reduced && _entranceOpen;

                  final nearby = all
                      .where(
                        (r) =>
                            r.distanceKm != null &&
                            r.distanceKm! <
                                TransitConstants.nearbyAlertsRadiusKm,
                      )
                      .toList();
                  final rest = all
                      .where((r) => !nearby.contains(r))
                      .where(
                        (r) =>
                            filter == null || r.alert.operatorId == filter.id,
                      )
                      .toList();

                  return [
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        'Cerca de ti',
                        subtitle: hasRealFix
                            ? 'A menos de 3 km'
                            : 'A menos de 3 km del centro de Bilbao',
                      ),
                    ),
                    if (nearby.isEmpty)
                      const SliverToBoxAdapter(child: _NearbyClear())
                    else
                      _AlertList(items: nearby, animate: animate),
                    const SliverToBoxAdapter(
                      child: SectionHeader('Toda la red'),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FilterBarDelegate(
                        selected: filter,
                        onSelected: _selectFilter,
                        textScale:
                            MediaQuery.textScalerOf(context).scale(15) / 15,
                      ),
                    ),
                    if (rest.isEmpty)
                      SliverToBoxAdapter(child: _AllClear(filter: filter))
                    else
                      _AlertList(
                        items: rest,
                        animate: animate,
                        indexOffset: nearby.length,
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _text = AppTypography.textTheme();

/// iOS large title, left aligned.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: _text.displayMedium!.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }
}

/// Where the incidents come from, and which operators aren't answering now
/// (a silent feed must not look like "no incidents").
class _SourceNotice extends ConsumerWidget {
  const _SourceNotice();

  static const _names = {
    'metro': 'Metro Bilbao',
    'bizkaibus': 'Bizkaibus',
    'euskotren': 'Euskotren',
    'renfe': 'Renfe',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(liveAlertsProvider).valueOrNull;
    final missing = [
      for (final op in data?.unavailable ?? const <String>[]) _names[op] ?? op,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SurfaceCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.verified_outlined,
                size: 18,
                color: AppColors.realtimeGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Incidencias oficiales en vigor de Metro Bilbao, Bizkaibus, '
                'Euskotren y Renfe.'
                '${missing.isEmpty ? '' : ' Ahora sin datos de: ${missing.join(', ')}.'}',
                style: _text.bodySmall!.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Cerca de ti" with nothing to report.
class _NearbyClear extends StatelessWidget {
  const _NearbyClear();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SurfaceCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.realtimeGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ninguna incidencia en tu zona.',
                style: _text.bodyMedium!.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for a filter in "Toda la red".
class _AllClear extends StatelessWidget {
  const _AllClear({required this.filter});

  final TransitOperator? filter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 12),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: ShapeDecoration(
              color: AppColors.realtimeGreen.withValues(alpha: 0.14),
              shape: const CircleBorder(),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 28,
              color: AppColors.realtimeGreen,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Todo en orden en la red',
            textAlign: TextAlign.center,
            style: _text.titleMedium!.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filter == null
                ? 'No hay incidencias abiertas.'
                : 'Sin incidencias en ${_filterLabel(filter)}.',
            textAlign: TextAlign.center,
            style: _text.bodySmall!.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky operator filter (navigation layer: glass)
// ---------------------------------------------------------------------------

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({
    required this.selected,
    required this.onSelected,
    required this.textScale,
  });

  final TransitOperator? selected;
  final ValueChanged<TransitOperator?> onSelected;
  final double textScale;

  double get _chipHeight => 36 * textScale.clamp(1.0, 1.5);

  @override
  double get minExtent => _chipHeight + 8 + 4 + 12;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: _OperatorFilterBar(
        selected: selected,
        onSelected: onSelected,
        chipHeight: _chipHeight,
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.selected != selected || old.textScale != textScale;
}

/// Glass capsule of operator filters; a lighter capsule springs to the
/// selected one, like the tab bar's droplet.
class _OperatorFilterBar extends StatefulWidget {
  const _OperatorFilterBar({
    required this.selected,
    required this.onSelected,
    required this.chipHeight,
  });

  final TransitOperator? selected;
  final ValueChanged<TransitOperator?> onSelected;
  final double chipHeight;

  @override
  State<_OperatorFilterBar> createState() => _OperatorFilterBarState();
}

class _OperatorFilterBarState extends State<_OperatorFilterBar> {
  static const _hPad = 14.0;
  static const _dot = 7.0;
  static const _dotGap = 6.0;
  static const _inset = 4.0;

  final _scroll = ScrollController();

  static const List<TransitOperator?> _options = [null, ..._filterOperators];

  TextStyle get _labelStyle =>
      _text.labelLarge!.copyWith(fontWeight: FontWeight.w600);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<double> _widths(TextScaler scaler) {
    return [
      for (final op in _options)
        () {
          final tp = TextPainter(
            text: TextSpan(text: _filterLabel(op), style: _labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = tp.width;
          tp.dispose();
          return (w + 2 * _hPad + (op == null ? 0 : _dot + _dotGap))
              .ceilToDouble();
        }(),
    ];
  }

  void _reveal(double left, double width, double viewport, bool reduced) {
    if (!_scroll.hasClients) return;
    final target = (left + width / 2 - viewport / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (reduced) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: Motion.smooth.duration,
        curve: Motion.smooth.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final widths = _widths(MediaQuery.textScalerOf(context));
    final lefts = <double>[];
    var x = 0.0;
    for (final w in widths) {
      lefts.add(x);
      x += w;
    }
    final total = x;
    final selectedIndex = math.max(0, _options.indexOf(widget.selected));
    final m = Motion.snappy;

    return LayoutBuilder(
      builder: (context, constraints) {
        final glassWidth = math.min(total + 2 * _inset, constraints.maxWidth);
        final viewport = glassWidth - 2 * _inset;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: glassWidth,
            child: GlassSurface(
              blur: true,
              radius: 999,
              padding: const EdgeInsets.all(_inset),
              child: SizedBox(
                height: widget.chipHeight,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: total,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          left: lefts[selectedIndex],
                          width: widths[selectedIndex],
                          top: 0,
                          bottom: 0,
                          duration: reduced ? Duration.zero : m.duration,
                          curve: m.curve,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _options.length; i++)
                                _FilterChip(
                                  operator: _options[i],
                                  width: widths[i],
                                  selected: i == selectedIndex,
                                  onTap: () {
                                    if (i == selectedIndex) return;
                                    HapticFeedback.selectionClick();
                                    widget.onSelected(_options[i]);
                                    _reveal(
                                        lefts[i], widths[i], viewport, reduced);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.operator,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final TransitOperator? operator;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _filterLabel(operator);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (operator != null) ...[
                  Container(
                    width: _OperatorFilterBarState._dot,
                    height: _OperatorFilterBarState._dot,
                    decoration: ShapeDecoration(
                      color: Color(operator!.colorHex),
                      shape: const CircleBorder(),
                    ),
                  ),
                  const SizedBox(width: _OperatorFilterBarState._dotGap),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: _text.labelLarge!.copyWith(
                      color: selected
                          ? AppColors.darkTextPrimary
                          : AppColors.darkTextSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      height: 1.0,
                    ),
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

// ---------------------------------------------------------------------------
// Alert cards (content layer: solid)
// ---------------------------------------------------------------------------

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.items,
    required this.animate,
    this.indexOffset = 0,
  });

  final List<RankedAlert> items;
  final bool animate;
  final int indexOffset;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _Entrance(
          key: ValueKey(items[i].alert.id),
          index: indexOffset + i,
          enabled: animate,
          child: _AlertCard(item: items[i]),
        ),
      ),
    );
  }
}

/// Fade + 8 px rise, 35 ms apart. Only the solid card is animated.
class _Entrance extends StatefulWidget {
  const _Entrance({
    super.key,
    required this.index,
    required this.enabled,
    required this.child,
  });

  final int index;
  final bool enabled;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  static const _length = 280;
  static const _step = 35;

  late final int _delay = _step * widget.index.clamp(0, 8);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delay + _length),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay / (_delay + _length),
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

typedef _Severity = ({String label, IconData icon, Color color});

_Severity _severityOf(String severity) => switch (severity) {
      'severe' => (
          label: 'Grave',
          icon: Icons.error_rounded,
          color: AppColors.disruptedRed,
        ),
      'warning' => (
          label: 'Aviso',
          icon: Icons.warning_rounded,
          color: AppColors.delayedAmber,
        ),
      _ => (
          label: 'Información',
          icon: Icons.info_rounded,
          color: AppColors.scheduledGray,
        ),
    };

String _formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item});

  final RankedAlert item;

  @override
  Widget build(BuildContext context) {
    final alert = item.alert;
    final op = TransitOperator.fromId(alert.operatorId);
    final severity = _severityOf(alert.severity);
    final distance = item.distanceKm;
    final stop = item.nearestStop;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: stop == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              StopDeparturesScreen.open(context, stop);
            },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Severity (icon + word, never colour alone) · operator · distance
                Row(
                  children: [
                    Icon(severity.icon, size: 16, color: severity.color),
                    const SizedBox(width: 5),
                    Text(
                      severity.label,
                      style: _text.labelMedium!.copyWith(
                        color: severity.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: _text.labelMedium!.copyWith(
                          color: AppColors.darkTextTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        op.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text.labelMedium!.copyWith(
                          color: AppColors.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (distance != null)
                      Text(
                        _formatDistance(distance),
                        style: AppTypography.time.copyWith(
                          color: AppColors.darkTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: LineBadge(
                        label: alert.lineName,
                        color: Color(op.colorHex),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: _text.titleMedium!.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _text.bodyMedium!.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                if (alert.activePeriod != null || stop != null) ...[
                  const SizedBox(height: 12),
                  const Divider(
                      height: 1, thickness: 1, color: AppColors.darkBorder),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (alert.activePeriod != null) ...[
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.darkTextSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            alert.activePeriod!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.time.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (stop != null) ...[
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Ver ${stop.name} ›',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text.labelLarge!.copyWith(
                              color: AppColors.accent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Severity bar on the leading edge; the card's continuous corners
          // clip it into a curved stroke.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: severity.color),
          ),
        ],
      ),
    );
  }
}
