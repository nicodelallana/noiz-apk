import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';

/// One upcoming departure: line badge, destination, the clock time with its
/// status in words, and a countdown readable at arm's length. The countdown
/// is green on time, amber when delayed and neutral for the timetable.
///
/// Fixed height so lists can use a fixed extent and skip layout passes.
class DepartureRow extends StatelessWidget {
  const DepartureRow({
    super.key,
    required this.departure,
    required this.operator,
    this.divider = false,
    this.padding = EdgeInsets.zero,
  });

  final Departure departure;
  final TransitOperator operator;

  /// Hairline above the row, for rows grouped inside one card.
  final bool divider;
  final EdgeInsetsGeometry padding;

  static const double _baseHeight = 68;

  /// Row height for the current text scale; use it as the list item extent.
  static double extentOf(BuildContext context) => MediaQuery.textScalerOf(
        context,
      ).scale(_baseHeight).clamp(_baseHeight, _baseHeight * 2);

  @override
  Widget build(BuildContext context) {
    final lineColor = Color(departure.routeColorHex ?? operator.colorHex);
    final isDelayed = departure.isRealtime && departure.delaySeconds >= 60;
    final countdownColor = !departure.isRealtime
        ? AppColors.darkTextPrimary
        : (isDelayed ? AppColors.delayedAmber : AppColors.realtimeGreen);
    final status = !departure.isRealtime
        ? 'Según horario'
        : isDelayed
            ? '+${departure.delaySeconds ~/ 60} min'
            : 'En directo';
    final t = AppTypography.textTheme();

    return Container(
      height: extentOf(context),
      padding: padding,
      decoration: divider
          ? const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.darkBorder, width: 0.7),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: LineBadge(
                label: departure.lineCode.isNotEmpty
                    ? departure.lineCode
                    : departure.line.id,
                color: lineColor,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.headsign,
                  style: t.titleMedium!.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${departure.scheduledTimeFormatted} · $status',
                  style: AppTypography.time.copyWith(
                    color: isDelayed
                        ? AppColors.delayedAmber
                        : AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CountdownText(
            minutes: departure.minutesRemaining,
            style: AppTypography.countdownSmall,
            color: countdownColor,
            unitStyle: t.bodySmall!.copyWith(
              color: AppColors.darkTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
