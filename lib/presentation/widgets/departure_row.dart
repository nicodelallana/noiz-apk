import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';

/// One upcoming departure: line badge, destination and a countdown readable
/// at arm's length. The countdown is green when on time, amber when delayed
/// and neutral when it is only the theoretical timetable.
///
/// Fixed height so lists can use a prototype extent and skip layout passes.
class DepartureRow extends StatelessWidget {
  const DepartureRow({
    super.key,
    required this.departure,
    required this.operator,
  });

  final Departure departure;
  final TransitOperator operator;

  static const double _baseHeight = 68;

  /// Row height for the current text scale; use it as the list item extent.
  static double extentOf(BuildContext context) => MediaQuery.textScalerOf(
        context,
      ).scale(_baseHeight).clamp(_baseHeight, _baseHeight * 2);

  @override
  Widget build(BuildContext context) {
    final lineColor = Color(departure.routeColorHex ?? operator.colorHex);
    final isDelayed = departure.isRealtime && departure.delaySeconds >= 60;
    final minutes = departure.minutesRemaining;

    final countdownColor = !departure.isRealtime
        ? AppColors.darkTextPrimary
        : (isDelayed ? AppColors.delayedAmber : AppColors.realtimeGreen);
    final caption = !departure.isRealtime
        ? 'Horario ${departure.scheduledTimeFormatted}'
        : isDelayed
            ? '+${departure.delaySeconds ~/ 60} min · ${departure.scheduledTimeFormatted}'
            : 'En hora · ${departure.scheduledTimeFormatted}';

    return SizedBox(
      height: extentOf(context),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              departure.lineCode.isNotEmpty
                  ? departure.lineCode
                  : departure.line.id,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.headsign,
                  style: const TextStyle(
                    color: AppColors.darkTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    color: isDelayed
                        ? AppColors.delayedAmber
                        : AppColors.darkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: minutes == 0 ? 'Ya' : '$minutes',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                if (minutes > 0)
                  const TextSpan(
                    text: ' min',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            style: TextStyle(
              color: countdownColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
