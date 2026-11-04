import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/map/map_transit_selector.dart';

void main() {
  group('MapTransitSelector UI Tests', () {
    testWidgets('renders all transit mode chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MapTransitSelector(),
            ),
          ),
        ),
      );

      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('Tren'), findsOneWidget);
      expect(find.text('Tranvía'), findsOneWidget);
      expect(find.text('Autobús'), findsOneWidget);
      expect(find.text('Funicular'), findsOneWidget);
    });

    testWidgets(
        'tapping Metro reveals Metro Bilbao operator chip and line picker',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MapTransitSelector(),
            ),
          ),
        ),
      );

      // Tap on 'Metro'
      await tester.tap(find.text('Metro'));
      await tester.pumpAndSettle();

      expect(container.read(mapSelectedModeProvider), TransitModeType.metro);
      expect(find.text('Metro Bilbao'), findsOneWidget);
    });

    testWidgets('tapping Autobús reveals bus operators', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MapTransitSelector(),
            ),
          ),
        ),
      );

      // Tap on 'Autobús'
      await tester.tap(find.text('Autobús'));
      await tester.pumpAndSettle();

      expect(container.read(mapSelectedModeProvider), TransitModeType.bus);
      expect(find.text('Bizkaibus'), findsOneWidget);
      expect(find.text('Bilbobus'), findsOneWidget);
    });

    testWidgets('tapping an operator reveals line picker button',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: MapTransitSelector(),
            ),
          ),
        ),
      );

      // Tap on 'Metro'
      await tester.tap(find.text('Metro'));
      await tester.pumpAndSettle();

      // Tap on 'Metro Bilbao' operator chip
      await tester.tap(find.text('Metro Bilbao'));
      await tester.pumpAndSettle();

      expect(
          container.read(mapSelectedOperatorProvider), TransitOperator.metro);
      expect(find.text('Ver rutas / líneas ▾'), findsOneWidget);
    });
  });
}
