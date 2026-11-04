import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bizkaia_transit/presentation/screens/splash/splash_screen.dart';

void main() {
  group('SplashScreen UI and Duration Tests', () {
    testWidgets(
        'renders app icon, shows no text (no Bizkaia/Transit/Noiz), and transitions quickly',
        (tester) async {
      var homeReached = false;

      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) {
              homeReached = true;
              return const Scaffold(body: Text('Home Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Verify initial frame shows the official app icon
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName == 'assets/icon/app_icon.png',
        ),
        findsOneWidget,
      );

      // Verify NO text is present on splash screen
      expect(find.byType(Text), findsNothing);
      expect(find.textContaining('Bizkaia', findRichText: true), findsNothing);
      expect(find.textContaining('Transit', findRichText: true), findsNothing);
      expect(find.textContaining('NOIZ', findRichText: true), findsNothing);

      // Verify no circular progress indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Advance clock by animation duration (350ms) + post frame
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();

      // Home should be reached without blocking on slow GPS or GTFS
      expect(homeReached, isTrue);
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
