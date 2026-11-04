import 'dart:async';

import 'package:bizkaia_transit/data/adapters/saved_trips_repository_impl.dart';
import 'package:bizkaia_transit/data/local/app_database.dart';
import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRawSavedTripRecord());
  });

  late MockAppDatabase mockDb;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late SavedTripsRepositoryImpl repo;

  setUp(() {
    mockDb = MockAppDatabase();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null); // Guest by default

    repo = SavedTripsRepositoryImpl(
      database: mockDb,
      supabaseClient: mockSupabase,
    );
  });

  group('SavedTripsRepositoryImpl', () {
    test('saveTrip writes to local SQLite immediately', () async {
      when(() => mockDb.insertOrUpdateSavedTrip(any()))
          .thenAnswer((_) async {});
      when(() => mockDb.getSavedTrips('guest')).thenAnswer((_) async => []);

      final trip = SavedTrip(
        id: 'trip_1',
        userId: 'guest',
        name: 'Casa al Trabajo',
        operator: TransitOperator.metro,
        originStopId: '35',
        originStopName: 'Bagatza',
        destStopId: '42',
        destStopName: 'Kabiezes',
        widgetEnabled: true,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 30, 8, 0, 0),
      );

      await repo.saveTrip(trip);

      verify(() => mockDb.insertOrUpdateSavedTrip(
          any(that: isA<RawSavedTripRecord>()))).called(1);
    });

    test('getSavedTrips maps raw records to domain SavedTrip entities',
        () async {
      final sampleRecord = RawSavedTripRecord(
        id: 'trip_1',
        userId: 'guest',
        name: 'Bagatza a Kabiezes',
        operatorId: 'metro',
        originStopId: '35',
        originStopName: 'Bagatza',
        destStopId: '42',
        destStopName: 'Kabiezes',
        routeId: 'MB',
        directionId: 1,
        widgetEnabled: true,
        sortOrder: 0,
        createdAt: '2026-09-30T08:00:00.000',
      );

      when(() => mockDb.getSavedTrips('guest'))
          .thenAnswer((_) async => [sampleRecord]);

      final trips = await repo.getSavedTrips();

      expect(trips.length, 1);
      final trip = trips.first;
      expect(trip.id, 'trip_1');
      expect(trip.name, 'Bagatza a Kabiezes');
      expect(trip.operator, TransitOperator.metro);
      expect(trip.originStopId, '35');
      expect(trip.destStopId, '42');
      expect(trip.widgetEnabled, isTrue);
    });

    test('migrateGuestTripsToUser re-assigns user_id in database', () async {
      final guestRecord = RawSavedTripRecord(
        id: 'guest_trip_1',
        userId: 'guest',
        name: 'Viaje Invitado',
        operatorId: 'metro',
        originStopId: '35',
        originStopName: 'Bagatza',
        destStopId: '42',
        destStopName: 'Kabiezes',
        widgetEnabled: true,
        sortOrder: 0,
        createdAt: '2026-09-30T08:00:00.000',
      );

      when(() => mockDb.getSavedTrips('guest'))
          .thenAnswer((_) async => [guestRecord]);
      when(() => mockDb.getSavedTrips('authenticated_user_123'))
          .thenAnswer((_) async => []);
      when(() => mockDb.updateTripUserId('guest', 'authenticated_user_123'))
          .thenAnswer((_) async {});

      // Mock Supabase from query
      final mockFrom = _MockSupabaseQueryBuilder();
      when(() => mockSupabase.from('saved_trips')).thenAnswer((_) => mockFrom);
      when(() => mockFrom.upsert(any()))
          .thenAnswer((_) => FakePostgrestFilterBuilder(<String, dynamic>{}));

      await repo.migrateGuestTripsToUser('authenticated_user_123');

      verify(() => mockDb.updateTripUserId('guest', 'authenticated_user_123'))
          .called(1);
    });
  });
}

class _MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakeRawSavedTripRecord extends Fake implements RawSavedTripRecord {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder([this._value]);
  final T? _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future<T?>.value(_value)
        .then((v) => onValue(v as T), onError: onError);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future<T?>.value(_value).then((v) => v as T).whenComplete(action);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future<T?>.value(_value)
        .then((v) => v as T)
        .catchError(onError, test: test);
  }
}
