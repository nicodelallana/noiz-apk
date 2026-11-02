import 'package:flutter_test/flutter_test.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';

void main() {
  group('Euskadi Multi-Operator Inventory Tests', () {
    test('contains all 13 recognized transport operators across Euskadi', () {
      final operators = TransitOperator.values;

      expect(operators.length, 13);

      final operatorIds = operators.map((o) => o.id).toSet();
      expect(operatorIds, containsAll([
        'metro',
        'bizkaibus',
        'bilbobus',
        'euskotren',
        'tranbia_bilbao',
        'tranbia_gasteiz',
        'renfe',
        'dbus',
        'lurraldebus',
        'tuvisa',
        'alavabus',
        'artxanda',
        'la_union',
      ]));
    });

    test('correctly maps territories (Bizkaia, Gipuzkoa, Araba)', () {
      final bizkaiaOps = TransitOperator.byTerritory(TransitTerritory.bizkaia);
      final gipuzkoaOps = TransitOperator.byTerritory(TransitTerritory.gipuzkoa);
      final arabaOps = TransitOperator.byTerritory(TransitTerritory.araba);

      expect(bizkaiaOps.map((o) => o.id), containsAll([
        'metro', 'bizkaibus', 'bilbobus', 'renfe', 'artxanda', 'tranbia_bilbao',
      ]));

      expect(gipuzkoaOps.map((o) => o.id), containsAll([
        'dbus', 'lurraldebus',
      ]));

      expect(arabaOps.map((o) => o.id), containsAll([
        'tuvisa', 'alavabus', 'tranbia_gasteiz', 'la_union',
      ]));
    });

    test('Departure status adheres to strict real-time vs scheduled classification', () {
      final now = DateTime.now();
      
      // Real-time departure
      final rtDeparture = Departure(
        tripId: 'rt_1',
        stationId: 'st_1',
        stationName: 'Abando',
        headsign: 'Kabiezes',
        line: MetroLine.l2,
        lineCode: 'L2',
        scheduledTime: now.add(const Duration(minutes: 3)),
        scheduledTimeFormatted: '14:35',
        minutesRemaining: 3,
        isRealtime: true,
        delaySeconds: 60,
        status: 'tracking',
      );

      // Scheduled-only departure (no RT feed)
      final schedDeparture = Departure(
        tripId: 'sched_1',
        stationId: 'st_2',
        stationName: 'Plaza Nueva',
        headsign: 'Vitoria-Gasteiz',
        line: MetroLine.l1,
        lineCode: 'A3714',
        scheduledTime: now.add(const Duration(minutes: 15)),
        scheduledTimeFormatted: '14:47',
        minutesRemaining: 15,
        isRealtime: false,
        status: 'scheduled',
      );

      expect(rtDeparture.isRealtime, true);
      expect(schedDeparture.isRealtime, false);

      // Verify that neither model text nor status ever mentions "horario teórico"
      expect(rtDeparture.toString().toLowerCase(), isNot(contains('horario teórico')));
      expect(schedDeparture.toString().toLowerCase(), isNot(contains('horario teórico')));
    });
  });
}
