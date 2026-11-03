import 'package:bizkaia_transit/domain/models/saved_trip_models.dart';
import 'package:bizkaia_transit/domain/models/transit_models.dart';

/// Pure domain model for multi-modal journey planning itineraries.
class TransitItinerary {
  const TransitItinerary({
    required this.origin,
    required this.destination,
    required this.totalDurationMinutes,
    required this.transfersCount,
    required this.departureTime,
    required this.arrivalTime,
    required this.legs,
  });

  final String origin;
  final String destination;
  final int totalDurationMinutes;
  final int transfersCount;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final List<TransitLeg> legs;
}

enum TransitLegType { transit, walk }

class TransitLeg {
  const TransitLeg({
    required this.type,
    required this.instruction,
    required this.originStopName,
    required this.destStopName,
    required this.durationMinutes,
    this.lineName,
    this.lineColorHex,
    this.operatorId,
    this.stopsCount = 0,
    this.distanceMeters,
  });

  final TransitLegType type;
  final String instruction;
  final String originStopName;
  final String destStopName;
  final int durationMinutes;
  final String? lineName;
  final String? lineColorHex;
  final String? operatorId;
  final int stopsCount;
  final int? distanceMeters;
}

/// Service alert notice for disruptions and notices across Euskadi.
class ServiceAlert {
  const ServiceAlert({
    required this.id,
    required this.operatorId,
    required this.territory,
    required this.lineName,
    required this.severity, // info | warning | severe
    required this.title,
    required this.description,
    this.activePeriod,
    this.affectedStopIds = const [],
    this.locations = const [],
    this.networkWide = false,
  });

  final String id;
  final String operatorId;
  final TransitTerritory territory;
  final String lineName;
  final String severity;
  final String title;
  final String description;
  final String? activePeriod;

  /// Stops informed by the alert (GTFS-RT `informed_entity.stop_id`), used
  /// to rank alerts by distance to the user.
  final List<String> affectedStopIds;

  /// Affected stops as named points, for alerts from the official feeds
  /// (their stop ids are the operators', not the app's).
  final List<AlertLocation> locations;

  /// Applies to the whole network (or no single place can be named).
  final bool networkWide;
}

/// A named place an alert affects.
class AlertLocation {
  const AlertLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

/// Unified Transit Repository for all operators and modes across Euskadi.
abstract class TransitRepository {
  Future<List<TransitOperator>> getOperators({TransitTerritory? territory});

  Future<List<Stop>> getStops({
    String? operatorId,
    TransitTerritory? territory,
    String? searchQuery,
  });

  Future<List<Departure>> getDepartures({
    required String stopId,
    String? destinationStopId,
    String? operatorId,
    DateTime? atTime,
  });

  Future<List<Stop>> getNearbyStops({
    required double latitude,
    required double longitude,
    double radiusKm = 1.5,
  });

  /// Stations of every operator inside the visible map region.
  Future<List<Stop>> getStopsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  });

  Future<Stop?> getStopById(String stopId);

  Future<List<TransitItinerary>> planRoute({
    required String origin,
    required String destination,
  });

  Future<List<ServiceAlert>> getServiceAlerts({
    TransitTerritory? territory,
    String? operatorId,
  });
}
