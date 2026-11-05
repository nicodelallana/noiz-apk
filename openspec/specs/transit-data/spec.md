# transit-data Specification

## Purpose
Manages offline schedule datasets, service day resolution (including GTFS times past 24:00:00), line classification rules, and statutory data attribution.

## Requirements

### Requirement: Datos de horarios offline
The system SHALL keep the latest downloaded schedule pack locally and use it when there is no network.

#### Scenario: Sin conexión
- **WHEN** the device is offline
- **THEN** next departures are computed from the local schedule and labelled "horario teórico"

### Requirement: Día de servicio correcto
The system SHALL resolve departures using the service day rules of GTFS, including times beyond 24:00:00 and Europe/Madrid time.

#### Scenario: Madrugada
- **WHEN** the current time is 00:26 and a trip is scheduled at 24:26:00 of the previous service day
- **THEN** that trip is included as an upcoming departure

### Requirement: Clasificación L1/L2 de Metro Bilbao
The system SHALL derive the metro line of each trip from the stations it serves, since the source feed has a single route.

#### Scenario: Viaje hacia Plentzia
- **WHEN** a Metro Bilbao trip serves stations between Lutxana and Plentzia
- **THEN** the system classifies the trip as Line 1 (L1)

#### Scenario: Viaje hacia Kabiezes
- **WHEN** a Metro Bilbao trip serves stations between Gurutzeta and Kabiezes
- **THEN** the system classifies the trip as Line 2 (L2)

### Requirement: Atribución de datos
The system SHALL display the data attributions required by each source's licence in Settings → About.

#### Scenario: Visualización de licencias
- **WHEN** the user navigates to Settings → About
- **THEN** attributions for CTB, Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, and Renfe are displayed

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
