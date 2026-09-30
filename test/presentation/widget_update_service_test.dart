import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';
import 'package:bizkaia_transit/domain/repositories/metro_repository.dart';
import 'package:bizkaia_transit/domain/repositories/saved_trips_repository.dart';
import 'package:bizkaia_transit/presentation/widgets/home_widget/widget_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMetroRepository extends Mock implements MetroRepository {}

class MockSavedTripsRepository extends Mock implements SavedTripsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMetroRepository mockMetroRepo;
  late MockSavedTripsRepository mockSavedTripsRepo;
  late WidgetUpdateService service;

  setUp(() {
    mockMetroRepo = MockMetroRepository();
    mockSavedTripsRepo = MockSavedTripsRepository();
    service = WidgetUpdateService(
      metroRepository: mockMetroRepo,
      savedTripsRepository: mockSavedTripsRepo,
    );
  });

  test(
      'WidgetUpdateService handles empty saved trips gracefully without throwing',
      () async {
    when(() => mockSavedTripsRepo.getSavedTrips())
        .thenAnswer((_) async => <SavedTrip>[]);

    await expectLater(service.update(), completes);
    verify(() => mockSavedTripsRepo.getSavedTrips()).called(1);
    verifyNever(() => mockMetroRepo.getDepartures(
          stationId: any(named: 'stationId'),
          destinationStopId: any(named: 'destinationStopId'),
          limit: any(named: 'limit'),
        ));
  });

  test('WidgetUpdateService fetches departures only for widgetEnabled trips',
      () async {
    final enabledTrip = SavedTrip(
      id: 'trip-1',
      userId: 'user-1',
      name: 'Casa -> Metro',
      operator: TransitOperator.metro,
      originStopId: '35',
      originStopName: 'Bagatza',
      destStopId: '38',
      destStopName: 'Kabiezes',
      widgetEnabled: true,
      createdAt: DateTime.now(),
    );

    final disabledTrip = SavedTrip(
      id: 'trip-2',
      userId: 'user-1',
      name: 'Otro viaje',
      operator: TransitOperator.metro,
      originStopId: '10',
      originStopName: 'San Mamés',
      destStopId: '12',
      destStopName: 'Moyua',
      widgetEnabled: false,
      createdAt: DateTime.now(),
    );

    when(() => mockSavedTripsRepo.getSavedTrips())
        .thenAnswer((_) async => [enabledTrip, disabledTrip]);

    when(() => mockMetroRepo.getDepartures(
          stationId: '35',
          destinationStopId: '38',
          limit: 8,
        )).thenAnswer((_) async => [
          Departure(
            tripId: 'mb-101',
            stationId: '35',
            stationName: 'Bagatza',
            headsign: 'Kabiezes',
            line: MetroLine.l2,
            scheduledTime: DateTime.now().add(const Duration(minutes: 6)),
            scheduledTimeFormatted: '12:30',
            minutesRemaining: 6,
          ),
        ]);

    await expectLater(service.update(), completes);

    verify(() => mockSavedTripsRepo.getSavedTrips()).called(1);
    verify(() => mockMetroRepo.getDepartures(
          stationId: '35',
          destinationStopId: '38',
          limit: 8,
        )).called(1);
    verifyNever(() => mockMetroRepo.getDepartures(
          stationId: '10',
          destinationStopId: any(named: 'destinationStopId'),
          limit: any(named: 'limit'),
        ));
  });
}
