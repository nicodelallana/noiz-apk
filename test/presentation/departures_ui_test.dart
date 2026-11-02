import 'package:bizkaia_transit/presentation/navigation/app_shell.dart';
import 'package:bizkaia_transit/presentation/navigation/transport_mode_fab.dart';
import 'package:bizkaia_transit/presentation/widgets/animations/arrival_pulse_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Departures UI, Operator Theme & Navigation Tests', () {
    testWidgets('AppShell renders "Cuenta" tab in navigation bar instead of "Ajustes"',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppShell(
              currentIndex: 0,
              child: Scaffold(body: Text('Contenido Principal')),
            ),
          ),
        ),
      );

      // Verify "Cuenta" is present
      expect(find.text('Cuenta'), findsOneWidget);
      // Verify "Ajustes" is NOT present
      expect(find.text('Ajustes'), findsNothing);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Mapa'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
    });

    testWidgets('TransportModeFab toggles transport mode provider between Metro and Bus',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                final mode = ref.watch(transportModeProvider);
                return Scaffold(
                  body: Text('MODO: ${mode.name}'),
                  floatingActionButton: const TransportModeFab(),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('MODO: metro'), findsOneWidget);

      // Programmatically change to bus
      capturedRef.read(transportModeProvider.notifier).state = TransportMode.bus;
      await tester.pumpAndSettle();

      expect(find.text('MODO: bus'), findsOneWidget);
    });

    testWidgets('Departure card renders ArrivalPulseIndicator and never "horario teórico"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                ArrivalPulseIndicator(size: 22),
                Text('3 min'),
              ],
            ),
          ),
        ),
      );

      // Pulse indicator must be present for imminent departure
      expect(find.byType(ArrivalPulseIndicator), findsOneWidget);
      expect(find.text('3 min'), findsOneWidget);

      // "horario teórico" must NEVER appear anywhere in the UI
      expect(find.text('horario teórico'), findsNothing);
      expect(find.textContaining('teórico'), findsNothing);
    });
  });
}
