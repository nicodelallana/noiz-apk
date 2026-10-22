import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_providers.dart';
import '../navigation/app_shell.dart';
import '../screens/alerts/alerts_placeholder_screen.dart';
import '../screens/auth/profile_settings_screen.dart';
import '../screens/metro/metro_departures_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/saved_trips/saved_trips_screen.dart';

/// Application router using GoRouter with auth-based redirects.
///
/// - Unauthenticated users are redirected to `/onboarding`.
/// - Authenticated users land on the main shell at `/`.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Watch auth state and guest onboarding skip flag for redirect recalculation
  final authState = ref.watch(authStateStreamProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,

    // ── Auth redirect ──────────────────────────────────────────────────
    redirect: (context, state) {
      final isAuthenticated =
          authState.whenData((user) => user != null).value ?? false;
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Not authenticated, has not completed/skipped onboarding, not on onboarding → redirect
      if (!isAuthenticated && !onboardingCompleted && !isOnboarding) {
        return '/onboarding';
      }

      // Authenticated but still on onboarding → go home
      if (isAuthenticated && isOnboarding) {
        return '/';
      }

      return null; // No redirect
    },

    // ── Routes ─────────────────────────────────────────────────────────
    routes: [
      // Onboarding (no shell)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main app with bottom navigation shell
      ShellRoute(
        builder: (context, state, child) {
          // Determine active tab from location
          final location = state.matchedLocation;
          final index = switch (location) {
            '/saved-trips' => 1,
            '/alerts' => 2,
            '/settings' => 3,
            _ => 0,
          };

          return AppShell(
            currentIndex: index,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MetroDeparturesScreen(),
            ),
          ),
          GoRoute(
            path: '/saved-trips',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SavedTripsScreen(),
            ),
          ),
          GoRoute(
            path: '/alerts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AlertsPlaceholderScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileSettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
