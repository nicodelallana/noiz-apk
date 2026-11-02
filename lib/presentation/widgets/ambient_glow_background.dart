import 'package:flutter/material.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';

/// Ambient backdrop with diffuse colored light spots matching the active
/// operator brand color, recreating the signature reference ambiance.
class AmbientGlowBackground extends StatelessWidget {
  const AmbientGlowBackground({
    super.key,
    required this.child,
    this.accentColor = AppColors.opMetroBilbao,
  });

  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark background base
        Positioned.fill(
          child: Container(
            color: AppColors.darkBackground,
          ),
        ),

        // Radiant diffuse orb at top center-left
        Positioned(
          top: -120,
          left: -60,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Secondary subtle orb top right
        Positioned(
          top: -80,
          right: -80,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
        ),

        // Foreground content
        child,
      ],
    );
  }
}
