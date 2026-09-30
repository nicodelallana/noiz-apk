import '../models/transit_models.dart';

/// Contract for Metro Bilbao data access.
/// Normalized domain interface decoupled from Drift SQLite and remote APIs.
abstract interface class MetroRepository {
  /// Fetches all Metro Bilbao stations (parent stations).
  /// Results are sorted alphabetically or by line progression.
  Future<List<Stop>> getStations({String? searchQuery});

  /// Finds a station by its parent ID or platform stop ID.
  Future<Stop?> getStationById(String stationId);

  /// Retrieves upcoming scheduled departures for a specific station.
  ///
  /// - [stationId]: Parent station ID (e.g. "35" for Bagatza) or specific stop ID.
  /// - [lineFilter]: Optional filter for [MetroLine.l1] or [MetroLine.l2].
  /// - [destinationStopId]: Optional filter by terminus/direction.
  /// - [limit]: Maximum number of departures to return (defaults to 15).
  /// - [referenceTime]: Baseline time in Europe/Madrid. Defaults to current time.
  Future<List<Departure>> getDepartures({
    required String stationId,
    MetroLine? lineFilter,
    String? destinationStopId,
    int limit = 15,
    DateTime? referenceTime,
  });

  /// Checks whether local transit schedule database is loaded and ready.
  Future<bool> isScheduleReady();
}
