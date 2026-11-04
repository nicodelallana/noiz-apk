import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/presentation/providers/transit_providers.dart';
import 'package:bizkaia_transit/presentation/screens/map/map_transit_selector.dart';

void main() {
  group('MapTransitSelector UI Tests', () {
    testWidgets(
        'renders top selector bar with territory, operator, and line label',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MapTransitSelector(),
            ),
          ),
        ),
      );

      expect(find.text('Bizkaia'), findsOneWidget);
      expect(find.text('Metro Bilbao'), findsOneWidget);
      expect(find.text('Todas las líneas'), findsOneWidget);
    });

    testWidgets('tapping selector bar opens transit selection modal sheet',
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

      // Tap on the top selector bar
      await tester.tap(find.byType(MapTransitSelector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal sheet is opened with title and sections
      expect(find.text('Elige transporte y línea'), findsOneWidget);
      expect(find.text('PROVINCIA / TERRITORIO'), findsOneWidget);
      expect(find.text('TIPO DE TRANSPORTE'), findsOneWidget);

      // Verify transport modes are present in modal sheet
      expect(find.text('Metro'), findsOneWidget);
      expect(find.text('Tren'), findsOneWidget);
      expect(find.text('Tranvía'), findsOneWidget);
      expect(find.text('Autobús'), findsOneWidget);
      expect(find.text('Funicular'), findsOneWidget);
    });

    testWidgets('tapping Autobús in modal sheet reveals bus operators',
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

      // Tap to open modal
      await tester.tap(find.byType(MapTransitSelector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on 'Autobús'
      await tester.tap(find.text('Autobús'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(mapSelectedModeProvider), TransitModeType.bus);
      expect(find.text('Bizkaibus'), findsAtLeast(1));
      expect(find.text('Bilbobus'), findsOneWidget);
    });

    testWidgets('switching territory to Álava sets default operator to Tuvisa',
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

      // Tap to open modal
      await tester.tap(find.byType(MapTransitSelector));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on 'Álava'
      await tester.tap(find.text('Álava'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(selectedTerritoryProvider), TransitTerritory.araba);
      expect(container.read(mapSelectedOperatorProvider), TransitOperator.tuvisa);
      expect(find.text('TUVISA'), findsAtLeast(1));
    });
  });
}
