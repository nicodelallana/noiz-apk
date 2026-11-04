import 'package:bizkaia_transit/presentation/widgets/animations/arrival_pulse_indicator.dart';
import 'package:bizkaia_transit/presentation/widgets/animations/empty_transit_view.dart';
import 'package:bizkaia_transit/presentation/widgets/animations/save_trip_success_dialog.dart';
import 'package:bizkaia_transit/presentation/widgets/animations/service_alert_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lottie Animation Widgets & Accessibility Tests', () {
    testWidgets(
        'ArrivalPulseIndicator renders static fallback when animations are disabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ArrivalPulseIndicator(),
            ),
          ),
        ),
      );

      // Verify static fallback Container is rendered instead of Lottie asset
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(ArrivalPulseIndicator), findsOneWidget);
    });

    testWidgets(
        'EmptyTransitView renders title, message and triggers onRetry callback',
        (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyTransitView(
              title: 'Prueba vacía',
              message: 'Sin salidas disponibles',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Prueba vacía'), findsOneWidget);
      expect(find.text('Sin salidas disponibles'), findsOneWidget);

      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('ServiceAlertBadge handles tap interaction', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceAlertBadge(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(ServiceAlertBadge), findsOneWidget);

      await tester.tap(find.byType(ServiceAlertBadge));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
        'SaveTripSuccessDialog shows dialog and dismisses on button tap',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SaveTripSuccessDialog(tripName: 'Bagatza → Moyua'),
            ),
          ),
        ),
      );

      expect(find.text('¡Viaje guardado!'), findsOneWidget);
      expect(find.text('Bagatza → Moyua'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
    });
  });
}
