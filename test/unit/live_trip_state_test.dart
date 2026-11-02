import 'package:flutter_test/flutter_test.dart';
import 'package:bizkaia_transit/domain/models/live_trip_models.dart';

void main() {
  group('LiveTripState Data Contract Tests', () {
    final now = DateTime.now();
    final arrival = now.add(const Duration(minutes: 7));

    final trip = LiveTripState(
      tripId: 'test_trip_123',
      operatorId: 'metro',
      mode: 'metro',
      lineId: 'L1',
      lineName: 'L1',
      lineColor: '#E2001A',
      origin: 'Plentzia',
      destination: 'Etxebarri',
      currentStop: 'San Mamés',
      nextStop: 'Indautxu',
      stopsRemaining: 5,
      progress: 0.65,
      arrivalTime: arrival,
      status: LiveTripStatus.tracking,
      isRealtime: true,
      delaySeconds: 120,
      instruction: 'Próxima parada: Indautxu',
      updatedAt: now,
    );

    test('toNativePayload and fromNativePayload roundtrip faithfully', () {
      final payload = trip.toNativePayload();

      expect(payload['tripId'], 'test_trip_123');
      expect(payload['operatorId'], 'metro');
      expect(payload['lineName'], 'L1');
      expect(payload['lineColor'], '#E2001A');
      expect(payload['origin'], 'Plentzia');
      expect(payload['destination'], 'Etxebarri');
      expect(payload['currentStop'], 'San Mamés');
      expect(payload['nextStop'], 'Indautxu');
      expect(payload['stopsRemaining'], 5);
      expect(payload['progress'], 0.65);
      expect(payload['status'], 'tracking');
      expect(payload['isRealtime'], true);
      expect(payload['delaySeconds'], 120);
      expect(payload['arrivalTimeEpochMs'], arrival.millisecondsSinceEpoch);

      final restored = LiveTripState.fromNativePayload(payload);
      expect(restored.tripId, trip.tripId);
      expect(restored.operatorId, trip.operatorId);
      expect(restored.status, LiveTripStatus.tracking);
      expect(restored.isRealtime, true);
      expect(restored.stopsRemaining, 5);
    });

    test('toJson and fromJson match Supabase backend schema', () {
      final json = trip.toJson();
      expect(json['tripId'], 'test_trip_123');
      expect(json['operatorId'], 'metro');
      expect(json['lineName'], 'L1');
      expect(json['lineColor'], '#E2001A');
      expect(json['isRealtime'], true);
      expect(json['delaySeconds'], 120);

      final fromJsonTrip = LiveTripState.fromJson(json);
      expect(fromJsonTrip.tripId, trip.tripId);
      expect(fromJsonTrip.status, LiveTripStatus.tracking);
    });

    test('minutesRemaining handles countdown to arrival timestamp', () {
      expect(trip.minutesRemaining, inInclusiveRange(6, 8));
      expect(trip.isArrivingSoon, true);
    });

    test('status transitions and copyWith update state accurately', () {
      final updated = trip.copyWith(
        status: LiveTripStatus.arriving,
        stopsRemaining: 1,
        progress: 0.95,
      );

      expect(updated.status, LiveTripStatus.arriving);
      expect(updated.stopsRemaining, 1);
      expect(updated.progress, 0.95);
    });
  });
}
