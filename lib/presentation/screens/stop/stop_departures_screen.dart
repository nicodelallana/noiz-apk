import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/departure_row.dart';

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
class StopDeparturesScreen extends ConsumerWidget {
  const StopDeparturesScreen({super.key, required this.stop});

  final Stop stop;

  static Future<void> open(BuildContext context, Stop stop) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StopDeparturesScreen(stop: stop)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operator = TransitOperator.fromId(stop.operatorId);
    final departures = ref.watch(departuresForStopProvider(stop));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(departuresForStopProvider(stop).future),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: const BackButton(),
              backgroundColor: AppColors.darkBackground,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    operator.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(operator.colorHex),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(operator.colorHex),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.trip_origin_rounded, size: 18),
                  label: const Text('Usar como origen'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    selectStopAsOrigin(ref, stop);
                    Navigator.of(context).pop();
                    context.go('/');
                  },
                ),
              ),
            ),
            ...departures.when(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No se han podido cargar las salidas.',
                      style: const TextStyle(color: AppColors.darkTextSecondary),
                    ),
                  ),
                ),
              ],
              data: (list) => list.isEmpty
                  ? const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Sin salidas programadas.',
                            style:
                                TextStyle(color: AppColors.darkTextSecondary),
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverFixedExtentList.builder(
                          itemExtent: DepartureRow.extentOf(context),
                          itemCount: list.length,
                          itemBuilder: (_, i) => DepartureRow(
                            departure: list[i],
                            operator: operator,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
