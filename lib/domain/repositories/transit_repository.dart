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

  /// Retrieves reachable destination stops from a given [originStopId]
  /// connected directly on the same line and trip.
  Future<List<Stop>> getReachableDestinations({
    required String originStopId,
    String? searchQuery,
    String? lineFilter,
  });

  Future<List<Departure>> getDepartures({
    required String stopId,
    String? destinationStopId,
    String? operatorId,
    DateTime? atTime,
    String? lineFilter,
  });

  /// Resolves which lines (e.g. A3336, A2336, L1) serve a specific station or stop.
  Future<List<String>> getServedLinesForStation(String stationId);

  Future<List<Stop>> getNearbyStops({
    required double latitude,
    required double longitude,
    double radiusKm = 1.5,
  });

  /// Stations and stops inside the visible map region.
  Future<List<Stop>> getStopsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    String? operatorId,
    String? mode,
    String? routeId,
    bool includePlatforms = false,
  });

  /// Retrieves all polyline coordinate paths [lon, lat] for all shapes/branches of a route.
  Future<List<List<List<double>>>> getRouteShapes(
    String routeId, {
    int? directionId,
  });

  /// Retrieves the primary polyline coordinates [lon, lat] for a route.
  Future<List<List<double>>> getRouteShape(
    String routeId, {
    int? directionId,
  });

  /// Retrieves GeoJSON LineString features for all routes of an operator.
  Future<Map<String, dynamic>> getOperatorNetworkGeoJson(String operatorId);

  /// Retrieves routes with optional filtering.
  Future<List<TransitRoute>> getRoutes({
    String? operatorId,
    String? mode,
    TransitTerritory? territory,
  });

  /// Retrieves ordered stops along a specific route and direction.
  Future<List<Stop>> getStopsForRoute(
    String routeId, {
    int? directionId,
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
