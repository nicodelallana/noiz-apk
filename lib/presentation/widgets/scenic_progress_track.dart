import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';

/// Animated visual track with vehicle glyph translating along the route,
/// faithfully reproducing the reference's `trayecto-hero__via` motion component.
class ScenicProgressTrack extends StatefulWidget {
  const ScenicProgressTrack({
    super.key,
    required this.progress, // 0.0 .. 1.0
    required this.lineColor,
    required this.mode, // 'metro' | 'train' | 'tram' | 'bus' | 'funicular'
    required this.originName,
    required this.destinationName,
    this.height = 36.0,
    this.showLabels = true,
  });

  final double progress;
  final Color lineColor;
  final String mode;
  final String originName;
  final String destinationName;
  final double height;
  final bool showLabels;

  @override
  State<ScenicProgressTrack> createState() => _ScenicProgressTrackState();
}

class _ScenicProgressTrackState extends State<ScenicProgressTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _iconForMode(String mode) {
    return switch (mode.toLowerCase()) {
      'bus' => BarikIcons.bus,
      'tram' => BarikIcons.tram,
      'funicular' => BarikIcons.cableCar,
      'metro' => BarikIcons.subway,
      _ => BarikIcons.train,
    };
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final vehicleIcon = _iconForMode(widget.mode);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              const vehicleSize = 24.0;
              final vehicleX =
                  (trackWidth * clampedProgress - (vehicleSize / 2))
                      .clamp(0.0, trackWidth - vehicleSize);

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 1. Background Inactive Rail
                  Container(
                    height: 6,
                    width: trackWidth,
                    decoration: BoxDecoration(
                      color: AppColors.darkSurfaceElevated,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // 2. Active Filled Colored Track
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    width: mathMax(trackWidth * clampedProgress, 6.0),
                    decoration: BoxDecoration(
                      color: widget.lineColor,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.lineColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  // 3. Origin Anchor Terminal Dot
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.darkTextSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // 4. Destination Terminal Pin Dot
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white60,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Translating Animated Vehicle Badge
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    left: vehicleX,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulseScale =
                            1.0 + (_pulseController.value * 0.06);
                        return Transform.scale(
                          scale: pulseScale,
                          child: Container(
                            width: vehicleSize,
                            height: vehicleSize,
                            decoration: BoxDecoration(
                              color: widget.lineColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      widget.lineColor.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              vehicleIcon,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.showLabels) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.originName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.destinationName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  double mathMax(double a, double b) => a > b ? a : b;
}
