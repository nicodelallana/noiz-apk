import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/widgets/glass/shapes.dart';

/// Instantaneous animated Splash Screen on startup.
/// - Centered official app icon with subtle branding glow.
/// - Minimalist aesthetic without text clutter.
/// - Snappy entry animation (~350ms) with zero blocking on GPS or database.
/// - Concurrent background warm-up of GTFS data and location.
/// - Smooth and immediate transition to Home ('/').
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
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndNavigate();
    });
  }

  Future<void> _initializeAndNavigate() async {
    // Warm up database stops & GPS in parallel in background
    unawaited(
      ref.read(resolvedUserLocationProvider.future).then<void>(
        (_) {},
        onError: (_) {},
      ),
    );
    unawaited(
      ref.read(stopsForActiveOperatorProvider.future).then<void>(
        (_) {},
        onError: (_) {},
      ),
    );

    // Respect user's motion preferences
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      if (mounted) context.go('/');
      return;
    }

    // Play entrance animation
    _controller.forward();

    // Allow comfortable time (~1200ms) for GPS & nearest stop resolution
    // so the user lands directly on their departures without seeing "Buscando parada…"
    await Future<void>.delayed(const Duration(milliseconds: 1200));

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
    return Scaffold(
      backgroundColor: const Color(0xFF06080C),
      body: Center(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF080E1C),
                      shape: continuousShape(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 1.2,
                        ),
                      ),
                      shadows: [
                        BoxShadow(
                          color: const Color(0xFF00C8FF).withValues(
                            alpha: 0.35 * _glowAnimation.value,
                          ),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: ContinuousClip(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
