import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bizkaia_transit/core/services/live_trip_service.dart';
import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/content.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/motion.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// The next departure, as the screen's hero: line and destination, a 72 pt
/// countdown, the clock time with its status in words, the departure after
/// it, and the "I'm taking this one" action that starts the lock-screen
/// notification. Solid surface (content layer), with a faint glow in the
/// line's colour. Materialises (scale + fade) when the departure changes.
class DepartureHeroCard extends ConsumerWidget {
  const DepartureHeroCard({
    super.key,
    required this.departure,
    required this.operator,
    required this.originName,
    this.followingDeparture,
    this.onTap,
  });

  final Departure departure;
  final TransitOperator operator;
  final String originName;

  /// The departure after this one, for "Después…" and the lock screen.
  final Departure? followingDeparture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTrip = ref.watch(activeLiveTripProvider);
    final isFollowingThis = activeTrip != null &&
        activeTrip.lineId == departure.lineCode &&
        activeTrip.destination == departure.headsign;

    final lineColor = Color(departure.routeColorHex ?? operator.colorHex);
    final delayMinutes =
        departure.isRealtime ? departure.delaySeconds ~/ 60 : 0;
    final t = AppTypography.textTheme();
    final reduced = Motion.reduced(context);
    final next = followingDeparture;

    final card = SurfaceCard(
      radius: 28,
      padding: EdgeInsets.zero,
      onTap: onTap,
      accent: isFollowingThis ? AppColors.realtimeGreen : null,
      child: Stack(
        children: [
          // Faint glow in the line's colour from the top-left corner.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.1, -1.2),
                    radius: 1.3,
                    colors: [
                      lineColor.withValues(alpha: 0.28),
                      lineColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LineBadge(
                      label: departure.lineCode,
                      color: lineColor,
                      large: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            departure.headsign,
                            style: t.titleLarge!.copyWith(
                              color: AppColors.darkTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'desde $originName',
                            style: t.bodySmall!.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (departure.isTomorrow) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'MAÑANA',
                          style: t.labelSmall!.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: CountdownText(
                          minutes: departure.minutesRemaining,
                          clockTime: departure.scheduledTimeFormatted,
                          color: delayMinutes > 0
                              ? AppColors.delayedAmber
                              : AppColors.darkTextPrimary,
                          unitStyle: t.titleLarge!.copyWith(
                            color: AppColors.darkTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            departure.minutesRemaining >= 60
                                ? 'en ${formatWait(departure.minutesRemaining)}'
                                : departure.scheduledTimeFormatted,
                            style: AppTypography.time.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          DepartureStatus(
                            isRealtime: departure.isRealtime,
                            delayMinutes: delayMinutes,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (next != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 16,
                        color: AppColors.darkTextTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Después: ${next.isTomorrow ? "Mañana " : ""}${next.scheduledTimeFormatted}'
                          ' (en ${formatWait(next.minutesRemaining)})',
                          style: AppTypography.time.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _FollowButton(
                  following: isFollowingThis,
                  label: isFollowingThis
                      ? 'Siguiendo en la pantalla de bloqueo'
                      : (operator.mode == TransitModeType.bus
                          ? 'Voy a coger este bus'
                          : 'Voy a coger este tren'),
                  onPressed: () => _toggleFollow(
                    context,
                    ref,
                    isFollowingThis: isFollowingThis,
                    lineColor: lineColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Materialise when the hero departure changes (not the glass layer:
    // this card is solid, so a fade is safe here).
    return TweenAnimationBuilder<double>(
      key: ValueKey(departure.tripId),
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.97 + 0.03 * v, child: child),
      ),
      child: card,
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref, {
    required bool isFollowingThis,
    required Color lineColor,
  }) async {
    HapticFeedback.mediumImpact();
    if (isFollowingThis) {
      await ref.read(activeLiveTripProvider.notifier).endTrip();
      return;
    }
    final isRealtime = departure.isRealtime;
    final arrival = DateTime.now().add(
      Duration(minutes: departure.minutesRemaining),
    );
    final liveTrip = LiveTripState(
      tripId: departure.tripId,
      operatorId: operator.id,
      mode: operator.mode.id,
      lineId: departure.lineCode,
      lineName: departure.lineCode,
      lineColor: '#${lineColor.toARGB32().toRadixString(16).substring(2)}',
      origin: originName,
      destination: departure.headsign,
      currentStop: originName,
      nextStop: departure.headsign,
      // Waiting at the origin: no in-vehicle progress yet.
      stopsRemaining: 0,
      progress: 0,
      arrivalTime: arrival,
      status: isRealtime ? LiveTripStatus.tracking : LiveTripStatus.scheduled,
      isRealtime: isRealtime,
      delaySeconds: departure.delaySeconds,
      updatedAt: DateTime.now(),
      operatorName: operator.name,
      platform: departure.platform,
      followingDepartureTime: followingDeparture?.scheduledTime,
    );

    final hasPerm = await ref.read(liveTripServiceProvider).requestPermission();
    await ref.read(activeLiveTripProvider.notifier).startTrip(liveTrip);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          backgroundColor: AppColors.darkSurfaceElevated,
          shape: continuousShape(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.darkBorderStrong),
          ),
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
}

/// Capsule action inside the hero card: solid accent when idle, a quiet
/// green outline while following. Springs down on press.
class _FollowButton extends StatefulWidget {
  const _FollowButton({
    required this.following,
    required this.label,
    required this.onPressed,
  });

  final bool following;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final m = _down ? Motion.snappy : Motion.bouncy;
    final following = widget.following;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down && !reduced ? Motion.pressedScale : 1,
          duration: reduced ? Duration.zero : m.duration,
          curve: m.curve,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : Motion.smooth.duration,
            curve: Motion.smooth.curve,
            height: 50,
            decoration: ShapeDecoration(
              color: following
                  ? AppColors.realtimeGreen.withValues(alpha: 0.12)
                  : AppColors.accent,
              shape: StadiumBorder(
                side: BorderSide(
                  color: following
                      ? AppColors.realtimeGreen.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  following
                      ? BarikIcons.checkCircle
                      : BarikIcons.navigationArrow,
                  size: 18,
                  color: following ? AppColors.realtimeGreen : Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme().labelLarge!.copyWith(
                          color: following
                              ? AppColors.realtimeGreen
                              : Colors.white,
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
