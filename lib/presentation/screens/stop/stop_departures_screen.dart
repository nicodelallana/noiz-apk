import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/departure_row.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/aurora_background.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/glass_surface.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';

/// Makes [stop] the home screen origin (switching operator if needed) and
/// clears any destination filter.
void selectStopAsOrigin(WidgetRef ref, Stop stop) {
  ref.read(selectedOperatorProvider.notifier).state =
      TransitOperator.fromId(stop.operatorId);
  ref.read(selectedTransitStopProvider.notifier).state = stop;
  ref.read(selectedDestinationStopProvider.notifier).state = null;
}

/// Whether [stop] can be the destination of the current origin: the
/// timetable only links stops of the same operator.
bool canBeDestination(WidgetRef ref, Stop stop) {
  final origin = ref.read(selectedTransitStopProvider);
  return origin != null &&
      origin.id != stop.id &&
      origin.operatorId == stop.operatorId;
}

/// Full departures board for one stop, pushed over the current tab with a
/// back button (from the map or from an alert).
class StopDeparturesScreen extends ConsumerStatefulWidget {
  const StopDeparturesScreen({super.key, required this.stop});

  final Stop stop;

  static Future<void> open(BuildContext context, Stop stop) {
    // A sliding push, never a cross-fade: the glass controls on this page
    // must not sit inside a fade, which breaks their blur.
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => StopDeparturesScreen(stop: stop),
      ),
    );
  }

  @override
  ConsumerState<StopDeparturesScreen> createState() =>
      _StopDeparturesScreenState();
}

class _StopDeparturesScreenState extends ConsumerState<StopDeparturesScreen> {
  static const _barHeight = 44.0;

  /// Scroll offset past which the large title has gone under the bar and
  /// the compact one takes over.
  static const _collapseAt = 64.0;

  final _scroll = ScrollController();

  double get _offset => _scroll.hasClients ? _scroll.offset : 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _useAsOrigin() {
    // The glass button already gives the haptic tick.
    selectStopAsOrigin(ref, widget.stop);
    Navigator.of(context).pop();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final operator = TransitOperator.fromId(stop.operatorId);
    final opColor = Color(operator.colorHex);
    final departures = ref.watch(departuresForStopProvider(stop));
    final padding = MediaQuery.paddingOf(context);
    final reduced = Motion.reduced(context);
    final t = AppTypography.textTheme();
    final contentTop = padding.top + 8 + _barHeight + 8;
    // Room for the shell's floating tab bar when pushed inside the shell.
    final bottomRoom = padding.bottom + 120;

    return AuroraBackground(
      animate: false,
      accent: opColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(departuresForStopProvider(stop).future),
              edgeOffset: contentTop,
              color: AppColors.accent,
              backgroundColor: AppColors.darkSurfaceElevated,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: contentTop)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LineBadge(label: operator.name, color: opColor),
                          const SizedBox(height: 10),
                          Semantics(
                            header: true,
                            child: Text(
                              stop.name,
                              style: t.displayMedium!.copyWith(
                                color: AppColors.darkTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SectionHeader('Próximas salidas'),
                  ),
                  ...departures.when(
                    loading: () => [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomRoom),
                          child: const Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    error: (e, _) => [
                      _FillMessage(
                        'No se han podido cargar las salidas.',
                        bottom: bottomRoom,
                      ),
                    ],
                    data: (list) => list.isEmpty
                        ? [
                            _FillMessage(
                              'Sin salidas programadas.',
                              bottom: bottomRoom,
                            ),
                          ]
                        : [
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: StopDeparturesCard(
                                departures: list,
                                operator: operator,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: bottomRoom),
                            ),
                          ],
                  ),
                ],
              ),
            ),
            // Scroll-edge fade: content dims as it slides under the controls.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: contentTop + 16,
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, child) => Opacity(
                    opacity: (_offset / 24).clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xEB06080C), Color(0x0006080C)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Tooltip(
                    message: 'Atrás',
                    excludeFromSemantics: true,
                    child: GlassButton(
                      semanticLabel: 'Atrás',
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.maybePop(context),
                      child: const SizedBox.square(
                        dimension: _barHeight,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 19,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Compact title once the large one has scrolled away.
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _scroll,
                      builder: (context, child) => AnimatedOpacity(
                        opacity: _offset > _collapseAt ? 1 : 0,
                        duration: reduced
                            ? Motion.reducedFade
                            : const Duration(milliseconds: 200),
                        child: child,
                      ),
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            stop.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall!.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  GlassButton(
                    tint: AppColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onPressed: _useAsOrigin,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trip_origin_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Usar como origen',
                          style: t.labelLarge!.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
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

class _FillMessage extends StatelessWidget {
  const _FillMessage(this.text, {required this.bottom});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme().bodyMedium!.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

/// A stop's departures grouped in one solid card: the [SurfaceCard] look as
/// a sliver, so long boards stay lazily built with a fixed row extent.
/// Shared by this screen and the map's stop sheet.
class StopDeparturesCard extends StatelessWidget {
  const StopDeparturesCard({
    super.key,
    required this.departures,
    required this.operator,
    this.radius = 24,
  });

  final List<Departure> departures;
  final TransitOperator operator;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedSliver(
      // Same fill and rim as SurfaceCard.
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF21A1D24), Color(0xF214161C)],
        ),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        sliver: SliverFixedExtentList.builder(
          itemExtent: DepartureRow.extentOf(context),
          itemCount: departures.length,
          itemBuilder: (_, i) => DepartureRow(
            departure: departures[i],
            operator: operator,
            divider: i > 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }
}
