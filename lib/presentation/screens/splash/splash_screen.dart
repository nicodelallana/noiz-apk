import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/core/theme/app_colors.dart';
import 'package:bizkaia_transit/core/theme/app_typography.dart';
import 'package:bizkaia_transit/core/theme/barik_icons.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Professional animated Splash Screen on startup.
/// - Minimalist, modern branding.
/// - Centered glowing symbol and typographic lockup.
/// - Fluid entry animation.
/// - Concurrent warm-up of local GTFS database & user position.
/// - Transitions automatically to Home ('/') with zero artificial wait.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    final stopwatch = Stopwatch()..start();

    // Warm up database stops & GPS in parallel without blocking UI
    try {
      await Future.wait([
        ref.read(resolvedUserLocationProvider.future),
        ref.read(stopsForActiveOperatorProvider.future),
      ]);
    } catch (_) {
      // Non-fatal: if permissions or offline, the app handles fallbacks
    }

    // Ensure at least minimum entry animation plays so it doesn't flash jarringly
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 600) {
      await Future<void>.delayed(Duration(milliseconds: 600 - elapsed));
    }

    if (mounted) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTypography.textTheme();

    return Scaffold(
      backgroundColor: const Color(0xFF06080C),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing logo badge
                    Container(
                      width: 88,
                      height: 88,
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE8590C),
                            Color(0xFFD0142B),
                          ],
                        ),
                        shape: continuousShape(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFFE8590C).withValues(
                              alpha: 0.45 * _glowAnimation.value,
                            ),
                            blurRadius: 36,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          BarikIcons.subway,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Title
                    Text(
                      'NOIZ',
                      style: t.displaySmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      'BIZKAIA TRANSIT',
                      style: t.labelMedium!.copyWith(
                        color: AppColors.darkTextSecondary,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Minimal subtle progress ring
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
