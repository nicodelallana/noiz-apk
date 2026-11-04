import 'package:bizkaia_transit/data/live/live_vehicles.dart';
import 'package:bizkaia_transit/presentation/screens/map/live_vehicles_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveVehicle _vehicle({
  required LivePositionKind kind,
  String? status,
  String operatorId = 'metro',
}) =>
    LiveVehicle(
      id: '$operatorId:1',
      operatorId: operatorId,
      kind: kind,
      latitude: 43.26,
      longitude: -2.94,
      line: kind == LivePositionKind.gps ? 'A3224' : 'L1',
      colorHex: kind == LivePositionKind.gps ? '#9CCD64' : '#FF6505',
      headsign: 'Plentzia',
      stopName: 'Moyua',
      status: status,
      reportedAt: DateTime.now().subtract(const Duration(seconds: 40)),
    );

Future<void> _pump(WidgetTester tester, LiveVehicle v) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: VehicleSheet(vehicle: v))),
    );

void main() {
  group('VehicleSheet honesty', () {
    testWidgets('a train placed by station is never presented as GPS',
        (tester) async {
      await _pump(tester,
          _vehicle(kind: LivePositionKind.station, status: 'in_transit'));

      // GTFS-RT IN_TRANSIT_TO: the stop is the one it is heading to.
      expect(find.text('Camino de Moyua'), findsOneWidget);
      expect(find.textContaining('Posición por estación'), findsOneWidget);
      expect(find.textContaining('No es GPS'), findsOneWidget);
      expect(find.textContaining('GPS en directo'), findsNothing);
    });

    testWidgets('stopped and incoming trains read as such', (tester) async {
      await _pump(
          tester, _vehicle(kind: LivePositionKind.station, status: 'stopped'));
      expect(find.text('En Moyua'), findsOneWidget);

      await _pump(
          tester, _vehicle(kind: LivePositionKind.station, status: 'incoming'));
      expect(find.text('Llegando a Moyua'), findsOneWidget);
    });

    testWidgets('a GPS bus says GPS and how old the fix is', (tester) async {
      await _pump(
        tester,
        _vehicle(kind: LivePositionKind.gps, operatorId: 'bizkaibus'),
      );

      expect(find.text('Cerca de Moyua'), findsOneWidget);
      expect(find.textContaining('GPS en directo · hace'), findsOneWidget);
      expect(find.textContaining('No es GPS'), findsNothing);
    });
  });
}
