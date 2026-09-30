import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/saved_trip_models.dart';
import '../../domain/repositories/saved_trips_repository.dart';
import '../local/app_database.dart';

/// Concrete implementation of [SavedTripsRepository] providing two-tier storage:
/// 1. Instant offline reads & writes from local Drift SQLite (`user_saved_trips`).
/// 2. Bidirectional cloud synchronization with Supabase Postgres (`saved_trips`).
class SavedTripsRepositoryImpl implements SavedTripsRepository {
  SavedTripsRepositoryImpl({
    required AppDatabase database,
    SupabaseClient? supabaseClient,
  })  : _db = database,
        _supabase = supabaseClient ?? Supabase.instance.client,
        _tripsStreamController = StreamController<List<SavedTrip>>.broadcast();

  final AppDatabase _db;
  final SupabaseClient _supabase;
  final StreamController<List<SavedTrip>> _tripsStreamController;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? 'guest';

  @override
  Stream<List<SavedTrip>> watchSavedTrips({String? userId}) {
    // Initial emission
    Future.microtask(() async {
      final trips = await getSavedTrips(userId: userId);
      if (!_tripsStreamController.isClosed) {
        _tripsStreamController.add(trips);
      }
    });
    return _tripsStreamController.stream;
  }

  @override
  Future<List<SavedTrip>> getSavedTrips({String? userId}) async {
    final effectiveUser = userId ?? _currentUserId;
    final records = await _db.getSavedTrips(effectiveUser);

    return records.map((r) => _mapRecordToDomain(r)).toList();
  }

  @override
  Future<SavedTrip?> getSavedTripById(String id) async {
    final record = await _db.getSavedTripById(id);
    if (record == null) return null;
    return _mapRecordToDomain(record);
  }

  @override
  Future<void> saveTrip(SavedTrip trip) async {
    final effectiveUser = trip.userId.isEmpty ? _currentUserId : trip.userId;
    final tripToSave = trip.userId.isEmpty ? trip.copyWith(userId: effectiveUser) : trip;

    // 1. Write to local SQLite first (guarantees offline availability)
    final record = RawSavedTripRecord(
      id: tripToSave.id,
      userId: tripToSave.userId,
      name: tripToSave.name,
      operatorId: tripToSave.operator.id,
      originStopId: tripToSave.originStopId,
      originStopName: tripToSave.originStopName,
      destStopId: tripToSave.destStopId,
      destStopName: tripToSave.destStopName,
      routeId: tripToSave.routeId,
      directionId: tripToSave.directionId,
      widgetEnabled: tripToSave.widgetEnabled,
      sortOrder: tripToSave.sortOrder,
      createdAt: tripToSave.createdAt.toIso8601String(),
    );
    await _db.insertOrUpdateSavedTrip(record);

    // 2. Notify reactive stream
    await _notifyStream(effectiveUser);

    // 3. Asynchronously sync to Supabase if authenticated
    if (effectiveUser != 'guest') {
      try {
        await _supabase.from('saved_trips').upsert({
          'id': tripToSave.id,
          'user_id': effectiveUser,
          'name': tripToSave.name,
          'operator': tripToSave.operator.id,
          'origin_stop_id': tripToSave.originStopId,
          'dest_stop_id': tripToSave.destStopId,
          'route_id': tripToSave.routeId,
          'direction_id': tripToSave.directionId,
          'widget_enabled': tripToSave.widgetEnabled,
          'sort_order': tripToSave.sortOrder,
          'created_at': tripToSave.createdAt.toIso8601String(),
        });
      } catch (_) {
        // Kept in local SQLite; will retry on next syncRemote()
      }
    }
  }

  @override
  Future<void> deleteTrip(String tripId) async {
    final effectiveUser = _currentUserId;

    // 1. Delete from local SQLite
    await _db.deleteSavedTrip(tripId);

    // 2. Notify reactive stream
    await _notifyStream(effectiveUser);

    // 3. Delete from Supabase if authenticated
    if (effectiveUser != 'guest') {
      try {
        await _supabase.from('saved_trips').delete().eq('id', tripId);
      } catch (_) {
        // Will reconcile on next remote sync
      }
    }
  }

  @override
  Future<void> toggleWidgetEnabled(String tripId, bool enabled) async {
    final effectiveUser = _currentUserId;

    // 1. Update local SQLite
    await _db.toggleTripWidget(tripId, enabled);

    // 2. Notify reactive stream
    await _notifyStream(effectiveUser);

    // 3. Update Supabase if authenticated
    if (effectiveUser != 'guest') {
      try {
        await _supabase.from('saved_trips').update({
          'widget_enabled': enabled,
        }).eq('id', tripId);
      } catch (_) {}
    }
  }

  @override
  Future<void> reorderTrips(List<String> orderedTripIds) async {
    final effectiveUser = _currentUserId;

    // 1. Update local SQLite
    await _db.reorderSavedTrips(orderedTripIds);

    // 2. Notify reactive stream
    await _notifyStream(effectiveUser);

    // 3. Sync updated sort order to Supabase
    if (effectiveUser != 'guest') {
      try {
        for (var i = 0; i < orderedTripIds.length; i++) {
          await _supabase.from('saved_trips').update({
            'sort_order': i,
          }).eq('id', orderedTripIds[i]);
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> syncRemote() async {
    final effectiveUser = _currentUserId;
    if (effectiveUser == 'guest') return;

    try {
      // 1. Pull remote trips from Supabase Postgres
      final response = await _supabase
          .from('saved_trips')
          .select()
          .eq('user_id', effectiveUser)
          .order('sort_order', ascending: true);

      final remoteTrips = (response as List<dynamic>).cast<Map<String, dynamic>>();

      for (final r in remoteTrips) {
        final originId = r['origin_stop_id'] as String;
        final destId = r['dest_stop_id'] as String;

        // Resolve station names from local stops database
        final originStop = await _db.getStopById(originId);
        final destStop = await _db.getStopById(destId);

        final localRecord = RawSavedTripRecord(
          id: r['id'] as String,
          userId: effectiveUser,
          name: (r['name'] as String?) ?? 'Viaje',
          operatorId: (r['operator'] as String?) ?? 'metro',
          originStopId: originId,
          originStopName: originStop?.stopName ?? originId,
          destStopId: destId,
          destStopName: destStop?.stopName ?? destId,
          routeId: r['route_id'] as String?,
          directionId: r['direction_id'] as int?,
          widgetEnabled: (r['widget_enabled'] as bool?) ?? true,
          sortOrder: (r['sort_order'] as int?) ?? 0,
          createdAt: (r['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        );

        await _db.insertOrUpdateSavedTrip(localRecord);
      }

      await _notifyStream(effectiveUser);
    } catch (_) {
      // Offline fallback: keep existing local trips intact
    }
  }

  @override
  Future<void> migrateGuestTripsToUser(String userId) async {
    // 1. Fetch any trips created anonymously in guest mode
    final guestTrips = await _db.getSavedTrips('guest');
    if (guestTrips.isEmpty) return;

    // 2. Re-assign user_id in SQLite
    await _db.updateTripUserId('guest', userId);

    // 3. Push all migrated trips to Supabase
    for (final trip in guestTrips) {
      try {
        await _supabase.from('saved_trips').upsert({
          'id': trip.id,
          'user_id': userId,
          'name': trip.name,
          'operator': trip.operatorId,
          'origin_stop_id': trip.originStopId,
          'dest_stop_id': trip.destStopId,
          'route_id': trip.routeId,
          'direction_id': trip.directionId,
          'widget_enabled': trip.widgetEnabled,
          'sort_order': trip.sortOrder,
          'created_at': trip.createdAt,
        });
      } catch (_) {}
    }

    await _notifyStream(userId);
  }

  Future<void> _notifyStream(String userId) async {
    if (!_tripsStreamController.isClosed) {
      final updated = await getSavedTrips(userId: userId);
      _tripsStreamController.add(updated);
    }
  }

  SavedTrip _mapRecordToDomain(RawSavedTripRecord r) {
    return SavedTrip(
      id: r.id,
      userId: r.userId,
      name: r.name,
      operator: TransitOperator.fromId(r.operatorId),
      originStopId: r.originStopId,
      originStopName: r.originStopName,
      destStopId: r.destStopId,
      destStopName: r.destStopName,
      routeId: r.routeId,
      directionId: r.directionId,
      widgetEnabled: r.widgetEnabled,
      sortOrder: r.sortOrder,
      createdAt: DateTime.tryParse(r.createdAt) ?? DateTime.now(),
    );
  }
}
