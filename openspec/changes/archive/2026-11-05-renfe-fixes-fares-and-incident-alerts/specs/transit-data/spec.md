# Spec Delta: transit-data

## ADDED Requirements

### Requirement: Resolución de cabeceras de viaje y destino Renfe Cercanías
The system SHALL resolve the destination of any trip whose GTFS headsign is empty, null, or blank whitespace using the terminal stop name from stop_times.

#### Scenario: Viaje de Renfe Cercanías con headsign vacío
- **WHEN** a Renfe Cercanías trip has no headsign in trips.txt
- **THEN** the system resolves the trip's destination to the name of its final scheduled stop instead of a generic fallback like "Destino"

### Requirement: Geometría canónica de líneas en el mapa sin zigzags
The system SHALL render a single canonical directional shape per line when displaying route networks or route paths on the map, preventing overlapping opposite-direction tracks from creating zig-zag and moiré artifacts.

#### Scenario: Zoom cercano en líneas de Metro y Renfe
- **WHEN** the user zooms in on a route or operator network on the map
- **THEN** lines are rendered cleanly along the canonical path without overlapping reverse-direction weave artifacts
