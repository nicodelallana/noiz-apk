import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/constants/transit_constants.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/stop/stop_departures_screen.dart';

/// Operators offered as filters for the "Toda la red" section.
const _filterOperators = [
  TransitOperator.metro,
  TransitOperator.bizkaibus,
  TransitOperator.euskotren,
  TransitOperator.renfe,
];

/// Operator filter for the "Toda la red" section; null shows every operator.
final _alertsOperatorFilterProvider =
    StateProvider.autoDispose<TransitOperator?>((ref) => null);

/// Service alerts ranked by distance: alerts within 3 km of the user first,
/// then the rest of the network with operator filters. Tapping an alert opens
/// the departures of its closest affected stop.
class ServiceAlertsScreen extends ConsumerWidget {
  const ServiceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranked = ref.watch(rankedServiceAlertsProvider);
    final filter = ref.watch(_alertsOperatorFilterProvider);
    final hasRealFix = ref.watch(userLocationProvider) != null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: RefreshIndicator(
        color: AppColors.delayedAmber,
        onRefresh: () async {
          ref.invalidate(serviceAlertsProvider);
          await ref.read(rankedServiceAlertsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.darkBackground,
              title: Text(
                'Incidencias',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _SampleDataNotice()),
            ...ranked.when(
              loading: () => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.delayedAmber,
                    ),
                  ),
                ),
              ],
              error: (_, __) => const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No se han podido cargar los avisos.',
                      style: TextStyle(color: AppColors.darkTextSecondary),
                    ),
                  ),
                ),
              ],
              data: (all) {
                final nearby = all
                    .where(
                      (r) =>
                          r.distanceKm != null &&
                          r.distanceKm! < TransitConstants.nearbyAlertsRadiusKm,
                    )
                    .toList();
                final rest = all
                    .where((r) => !nearby.contains(r))
                    .where((r) => filter == null || r.alert.operatorId == filter.id)
                    .toList();

                return [
                  _SectionHeader(
                    title: 'Cerca de ti',
                    subtitle: hasRealFix
                        ? 'A menos de 3 km'
                        : 'A menos de 3 km del centro de Bilbao',
                  ),
                  if (nearby.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          'Ninguna incidencia en tu zona.',
                          style: TextStyle(color: AppColors.darkTextSecondary),
                        ),
                      ),
                    )
                  else
                    _AlertList(items: nearby),
                  const _SectionHeader(title: 'Toda la red'),
                  SliverToBoxAdapter(
                    child: _OperatorChips(
                      selected: filter,
                      onSelected: (op) => ref
                          .read(_alertsOperatorFilterProvider.notifier)
                          .state = op,
                    ),
                  ),
                  if (rest.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sin incidencias para este filtro.',
                          style: TextStyle(color: AppColors.darkTextSecondary),
                        ),
                      ),
                    )
                  else
                    _AlertList(items: rest),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The alerts feed is not connected yet: say so instead of passing the
/// bundled examples off as live incidents.
class _SampleDataNotice extends StatelessWidget {
  const _SampleDataNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.darkTextSecondary,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Avisos de ejemplo: la conexión con los avisos oficiales de '
              'los operadores aún no está activa.',
              style: TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OperatorChips extends StatelessWidget {
  const _OperatorChips({required this.selected, required this.onSelected});

  final TransitOperator? selected;
  final ValueChanged<TransitOperator?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TransitOperator? op) {
      final isSel = selected == op;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: isSel,
          showCheckmark: false,
          label: Text(label),
          labelStyle: TextStyle(
            color: isSel ? Colors.white : AppColors.darkTextSecondary,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
          backgroundColor: AppColors.darkSurface,
          selectedColor: op == null
              ? AppColors.darkSurfaceElevated
              : Color(op.colorHex),
          side: const BorderSide(color: AppColors.darkBorder),
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onSelected(op);
          },
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Todas', null),
          for (final op in _filterOperators)
            chip(op == TransitOperator.renfe ? 'Cercanías' : op.name, op),
        ],
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.items});

  final List<RankedAlert> items;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _AlertCard(item: items[i]),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item});

  final RankedAlert item;

  @override
  Widget build(BuildContext context) {
    final alert = item.alert;
    final op = TransitOperator.fromId(alert.operatorId);
    final severityColor = switch (alert.severity) {
      'severe' => AppColors.disruptedRed,
      'warning' => AppColors.delayedAmber,
      _ => AppColors.scheduledGray,
    };
    final distance = item.distanceKm;
    final stop = item.nearestStop;

    return Material(
      color: AppColors.darkSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: stop == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                StopDeparturesScreen.open(context, stop);
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: severityColor, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(op.colorHex),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alert.lineName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      op.name,
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (distance != null)
                    Text(
                      distance < 1
                          ? '${(distance * 1000).round()} m'
                          : '${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                alert.title,
                style: const TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.description,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (alert.activePeriod != null || stop != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (alert.activePeriod != null)
                      Text(
                        alert.activePeriod!,
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Spacer(),
                    if (stop != null)
                      Text(
                        'Ver ${stop.name} ›',
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
