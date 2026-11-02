import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/presentation/navigation/app_shell.dart';
import 'package:bizkaia_transit/presentation/providers/auth_providers.dart';
import 'package:bizkaia_transit/presentation/screens/alerts/service_alerts_screen.dart';
import 'package:bizkaia_transit/presentation/screens/auth/profile_settings_screen.dart';
import 'package:bizkaia_transit/presentation/screens/legal/licenses_screen.dart';
import 'package:bizkaia_transit/presentation/screens/map/transit_map_screen.dart';
import 'package:bizkaia_transit/presentation/screens/metro/metro_departures_screen.dart';
import 'package:bizkaia_transit/presentation/screens/nearby/nearby_transit_screen.dart';
import 'package:bizkaia_transit/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:bizkaia_transit/presentation/screens/planner/route_planner_screen.dart';
import 'package:bizkaia_transit/presentation/screens/saved_trips/saved_trips_screen.dart';

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
            '/map' => 1,
            '/alerts' => 2,
            '/settings' || '/settings/licenses' => 3,
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
            path: '/map',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransitMapScreen(),
            ),
          ),
          // Saved trips left the tab bar for the map; still reachable from
          // the home menu because they feed the home-screen widget.
          GoRoute(
            path: '/saved-trips',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SavedTripsScreen(),
            ),
          ),
          GoRoute(
            path: '/alerts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ServiceAlertsScreen(),
            ),
          ),
          GoRoute(
            path: '/nearby',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NearbyTransitScreen(),
            ),
          ),
          GoRoute(
            path: '/routes',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RoutePlannerScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileSettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'licenses',
                builder: (context, state) => const LicensesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
