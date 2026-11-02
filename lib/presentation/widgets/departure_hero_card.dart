import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/widgets/animations/arrival_pulse_indicator.dart';
import 'package:bizkaia_transit/presentation/widgets/scenic_progress_track.dart';

/// Next Departure Hero Card, matching the reference's primary layout.
/// Features big countdown, line badge, live delay state, and animated rail track.
class DepartureHeroCard extends ConsumerWidget {
  const DepartureHeroCard({
    super.key,
    required this.departure,
    required this.operator,
    required this.originName,
    this.onTap,
  });

  final Departure departure;
  final TransitOperator operator;
  final String originName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTrip = ref.watch(activeLiveTripProvider);
    final isFollowingThis = activeTrip != null &&
        activeTrip.lineId == departure.lineCode &&
        activeTrip.destination == departure.headsign;

    final brandColor = Color(operator.colorHex);
    final delaySeconds = departure.delaySeconds;
    final isRealtime = departure.isRealtime;

    final statusColor = delaySeconds > 60
        ? AppColors.delayedAmber
        : (isRealtime ? AppColors.realtimeGreen : AppColors.scheduledGray);

    final statusLabel = delaySeconds > 60
        ? '+${delaySeconds ~/ 60} min'
        : (isRealtime ? 'En directo' : 'Según horario');

    return Card(
      elevation: 0,
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isFollowingThis
              ? brandColor.withValues(alpha: 0.6)
              : AppColors.darkBorderStrong,
          width: isFollowingThis ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Line Chip + Destination + Status Dot
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      departure.lineCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      departure.headsign,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkTextPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Realtime / Delay Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Metric Row: Scheduled Time vs Countdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Scheduled Clock Time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        departure.scheduledTimeFormatted,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (delaySeconds > 60) ...[
                    const SizedBox(width: 6),
                    Text(
                      departure.scheduledTimeFormatted,
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Massive Countdown with pulse when imminent
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (departure.minutesRemaining <= 3 && isRealtime) ...[
                        const ArrivalPulseIndicator(size: 24),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '${departure.minutesRemaining}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: departure.minutesRemaining <= 3
                              ? AppColors.realtimeGreen
                              : AppColors.darkTextPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'min',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Scenic Progress Track Line
              ScenicProgressTrack(
                progress: departure.progress > 0.0 ? departure.progress : 0.35,
                lineColor: brandColor,
                mode: operator.mode.id,
                originName: originName,
                destinationName: departure.headsign,
              ),

              const SizedBox(height: 16),

              // Action Row: "Voy a coger este tren / Seguir viaje"
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    if (isFollowingThis) {
                      await ref.read(activeLiveTripProvider.notifier).endTrip();
                    } else {
                      final arrival = DateTime.now().add(
                        Duration(minutes: departure.minutesRemaining),
                      );

                      final liveTrip = LiveTripState(
                        tripId: departure.tripId,
                        operatorId: operator.id,
                        mode: operator.mode.id,
                        lineId: departure.lineCode,
                        lineName: departure.lineCode,
                        lineColor:
                            '#${brandColor.toARGB32().toRadixString(16).substring(2)}',
                        origin: originName,
                        destination: departure.headsign,
                        currentStop: originName,
                        nextStop: departure.headsign,
                        stopsRemaining: 4,
                        progress: 0.25,
                        arrivalTime: arrival,
                        status: isRealtime
                            ? LiveTripStatus.tracking
                            : LiveTripStatus.scheduled,
                        isRealtime: isRealtime,
                        delaySeconds: delaySeconds,
                        instruction: 'Bájate en ${departure.headsign}',
                        updatedAt: DateTime.now(),
                      );

                      final hasPerm = await ref
                          .read(liveTripServiceProvider)
                          .requestPermission();

                      await ref
                          .read(activeLiveTripProvider.notifier)
                          .startTrip(liveTrip);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.darkSurfaceElevated,
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppColors.realtimeGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    hasPerm
                                        ? 'Siguiendo ${departure.lineCode} a ${departure.headsign} en la pantalla de bloqueo'
                                        : 'Viaje iniciado. Si no ves la notificación en bloqueo, activa los avisos en ajustes.',
                                    style: const TextStyle(
                                      color: AppColors.darkTextPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    isFollowingThis
                        ? BarikIcons.checkCircle
                        : BarikIcons.navigationArrow,
                    size: 18,
                  ),
                  label: Text(
                    isFollowingThis
                        ? 'Siguiendo en pantalla de bloqueo'
                        : (operator.mode == TransitModeType.bus
                            ? 'Voy a coger este bus'
                            : 'Voy a coger este tren'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isFollowingThis
                        ? AppColors.darkSurfaceElevated
                        : brandColor,
                    foregroundColor: isFollowingThis
                        ? AppColors.realtimeGreen
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isFollowingThis
                          ? const BorderSide(color: AppColors.realtimeGreen)
                          : BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
