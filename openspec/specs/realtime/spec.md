# realtime Specification

## Purpose
Processes real-time vehicle positions and trip updates from GTFS-RT feeds, adjusts theoretical departure times, and handles cancellations and skipped stops.

## Requirements

### Requirement: Retrasos en tiempo real
The system SHALL overlay real-time delays from GTFS-RT trip updates on scheduled departures when the feed is fresh (timestamp < 2 minutes for buses, < 1 minute for metro).

#### Scenario: Feed caído
- **WHEN** a real-time feed returns an error or stale data
- **THEN** scheduled times are shown with a "sin tiempo real" indicator and no crash occurs

#### Scenario: Retraso actualizado
- **WHEN** a fresh GTFS-RT trip update is received with delay information
- **THEN** the departure time reflects the real-time delay relative to the scheduled time

### Requirement: Viajes cancelados y paradas omitidas
The system SHALL hide canceled trips and mark skipped stops.

#### Scenario: Viaje cancelado
- **WHEN** a real-time update marks a trip as CANCELED
- **THEN** the trip is excluded from active upcoming departures

#### Scenario: Parada omitida
- **WHEN** a real-time update marks a stop as SKIPPED
- **THEN** that stop is visibly marked as skipped on the route details
