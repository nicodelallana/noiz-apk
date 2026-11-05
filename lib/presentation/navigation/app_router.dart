import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/presentation/navigation/app_shell.dart';
import 'package:bizkaia_transit/presentation/screens/alerts/service_alerts_screen.dart';
import 'package:bizkaia_transit/presentation/screens/fares/transit_fares_screen.dart';
import 'package:bizkaia_transit/presentation/screens/legal/licenses_screen.dart';
import 'package:bizkaia_transit/presentation/screens/map/transit_map_screen.dart';
import 'package:bizkaia_transit/presentation/screens/metro/metro_departures_screen.dart';
import 'package:bizkaia_transit/presentation/screens/nearby/nearby_transit_screen.dart';
import 'package:bizkaia_transit/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:bizkaia_transit/presentation/screens/planner/route_planner_screen.dart';
import 'package:bizkaia_transit/presentation/screens/saved_trips/saved_trips_screen.dart';
import 'package:bizkaia_transit/presentation/screens/splash/splash_screen.dart';

/// Application router using GoRouter with sleek animated splash startup.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,

    // ── Routes ─────────────────────────────────────────────────────────
    routes: [
      // Animated splash screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding (optional secondary flow)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Main app: one branch per tab, kept alive in an IndexedStack. Leaving
      // a tab no longer destroys it, so coming back is instant — above all
      // the map, which otherwise re-created its MapLibre view (and refetched
      // its style) on every visit.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          currentIndex: navigationShell.currentIndex,
          child: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MetroDeparturesScreen(),
                ),
              ),
              // Saved trips left the tab bar for the map; still reachable
              // from the home menu because they feed the home-screen widget.
              GoRoute(
                path: '/saved-trips',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SavedTripsScreen(),
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TransitMapScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ServiceAlertsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/fares',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TransitFaresScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'licenses',
                    builder: (context, state) => const LicensesScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/settings',
                redirect: (context, state) => '/fares',
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
