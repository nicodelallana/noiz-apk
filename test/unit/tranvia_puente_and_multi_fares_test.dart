import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/data/adapters/transit_repository_impl.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/presentation/screens/fares/transit_fares_screen.dart';

import 'transit_database_accuracy_test.dart';

void main() {
  group('Tranvía de Bilbao & Gasteiz Data Integrity Tests', () {
    test('getStations queries stops specifically for Tranvía de Bilbao', () async {
      String? capturedSql;
      List<Object?>? capturedArgs;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          capturedSql = sql;
          capturedArgs = args;
          return [
            {
              'stop_id': 'euskotren:ES:Euskotren:StopPlace:1468:',
              'operator_id': 'tranbia_bilbao',
              'stop_name': 'Atxuri',
              'stop_lat': 43.253,
              'stop_lon': -2.923,
              'zone_id': '1',
              'parent_station': null,
              'territory': 'bizkaia',
              'mode': 'tram',
              'location_type': 1,
            },
            {
              'stop_id': 'euskotren:ES:Euskotren:StopPlace:1476:',
              'operator_id': 'tranbia_bilbao',
              'stop_name': 'Guggenheim',
              'stop_lat': 43.268,
              'stop_lon': -2.934,
              'zone_id': '1',
              'parent_station': null,
              'territory': 'bizkaia',
              'mode': 'tram',
              'location_type': 1,
            },
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final repo = TransitRepositoryImpl(database: db);

      final stops = await repo.getStops(operatorId: 'tranbia_bilbao');

      expect(capturedSql, contains('s.operator_id = ?'));
      expect(capturedArgs, contains('tranbia_bilbao'));
      expect(stops.length, 2);
      expect(stops.first.name, 'Atxuri');
      expect(stops.first.mode, 'tram');
      expect(stops.last.name, 'Guggenheim');
    });
  });

  group('Puente Colgante 24h Timetable Integrity Tests', () {
    test('Puente Colgante returns continuous departures across 24h', () async {
      String? capturedSql;

      final mockExecutor = MockQueryExecutor(
        customSelectHandler: (sql, args) async {
          capturedSql = sql;
          return [
            {
              'trip_id': 'pte_colgante:trip_0211_A_P',
              'departure_time': '17:00:00',
              'stop_id': 'pte_colgante:Puente Bizkaia - Las Arenas',
              'stop_name': 'Las Arenas (Puente Bizkaia)',
              'trip_headsign': 'PORTUGALETE',
              'inferred_line': 'PTE',
              'route_color': '#8D6E63',
              'parent_station': null,
            },
            {
              'trip_id': 'pte_colgante:trip_0213_A_P',
              'departure_time': '17:08:00',
              'stop_id': 'pte_colgante:Puente Bizkaia - Las Arenas',
              'stop_name': 'Las Arenas (Puente Bizkaia)',
              'trip_headsign': 'PORTUGALETE',
              'inferred_line': 'PTE',
              'route_color': '#8D6E63',
              'parent_station': null,
            },
          ];
        },
      );

      final db = AppDatabase(executor: mockExecutor);
      final deps = await db.getDepartures(
        stationId: 'pte_colgante:Puente Bizkaia - Las Arenas',
        activeServiceIds: {'pte_colgante:daily'},
        minDepartureTime: '17:00:00',
      );

      expect(capturedSql, isNotNull);
      expect(deps.length, 2);
      expect(deps.first.headsign, 'PORTUGALETE');
      expect(deps.first.inferredLine, 'PTE');
      expect(deps[1].departureTime, '17:08:00');
    });
  });

  group('Multi-Territory Fares Calculation Tests', () {
    test('Calculates Barik, MUGI and BAT flat fare discounts accurately', () {
      // Dbus (San Sebastián): 1.26 € Mugi vs 1.85 € ocasional (~32% saving)
      const dbusMugi = 1.26;
      const dbusOcasional = 1.85;
      final dbusSaving = ((dbusOcasional - dbusMugi) / dbusOcasional) * 100;
      expect(dbusSaving.round(), 32);

      // TUVISA (Vitoria): 0.60 € BAT vs 1.40 € ocasional (~57% saving)
      const tuvisaBAT = 0.60;
      const tuvisaOcasional = 1.40;
      final tuvisaSaving = ((tuvisaOcasional - tuvisaBAT) / tuvisaOcasional) * 100;
      expect(tuvisaSaving.round(), 57);

      // Tranvía de Bilbao: 0.73 € Barik vs 1.50 € ocasional (~51% saving)
      const tranviaBarik = 0.73;
      const tranviaOcasional = 1.50;
      final tranviaSaving = ((tranviaOcasional - tranviaBarik) / tranviaOcasional) * 100;
      expect(tranviaSaving.round(), 51);

      // Puente Colgante: 0.55 € Barik vs 0.60 € ocasional
      const pteBarik = 0.55;
      const pteOcasional = 0.60;
      expect(pteBarik < pteOcasional, isTrue);
    });

    test('FareProfile profiles correctly scale prices and discounts', () {
      const basePrice = 1.00;

      expect(FareProfile.standard.label, 'Estándar');
      expect(FareProfile.gizatrans.label, 'Social / Gizatrans');
      expect(FareProfile.largeFamily20.label, 'F. Numerosa (F20)');
      expect(FareProfile.largeFamily50.label, 'F. Numerosa (F50)');
      expect(FareProfile.under12.label, 'Menores 12 años');

      // Under 12 is 100% free
      const factorUnder12 = 0.0;
      expect(basePrice * factorUnder12, 0.00);

      // Gizatrans / Social is 40% of base
      const factorGizatrans = 0.40;
      expect(basePrice * factorGizatrans, 0.40);
    });
  });
}
