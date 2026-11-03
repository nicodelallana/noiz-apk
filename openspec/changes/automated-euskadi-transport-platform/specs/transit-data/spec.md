# Spec Delta: Automated Euskadi Public Transport Data Ingestion & Provincial Management

## ADDED REQUIREMENTS

### Requirement: Descubrimiento dinámico del catálogo Moveuskadi
The system SHALL continuously query the authoritative Moveuskadi JSON index at `https://opendata.euskadi.eus/transport/moveuskadi/data-index.json`, discover all published operators and resource entries dynamically, and register new operators without manual configuration or schema changes.

#### Scenario: Nuevo operador aparece en el índice
- **WHEN** the JSON catalogue is polled and contains a previously unseen operator name
- **THEN** the system creates a new entry in `transport_operators`, records its available resource formats, and registers ingestion jobs for its resources

#### Scenario: Fallo de red temporal en el catálogo
- **WHEN** the catalogue retrieval encounters an HTTP timeout or network error
- **THEN** the system logs the failure with exponential backoff retries and preserves all existing active operators and feeds without dropping production data

---

### Requirement: Prevención estricta de colisión de identificadores entre operadores
The system SHALL isolate entities belonging to different transit operators by scoping external identifiers with a source namespace `(operator_id, external_id)` and internal UUID primary keys.

#### Scenario: Dos operadores publican el mismo stop_id
- **WHEN** Metro Bilbao and Bizkaibus both publish a stop with external ID `"1"`
- **THEN** the system generates distinct internal UUIDs for each stop and inserts both records without violating unique constraints or overwriting data

---

### Requirement: Clasificación provincial geográfica estricta
The system SHALL classify all transit stops into Bizkaia, Gipuzkoa, or Araba / Álava by executing spatial containment checks against official Basque Government territorial boundary polygons in PostGIS (`EPSG:4326`).

#### Scenario: Parada situada dentro del municipio de Bilbao
- **WHEN** a stop coordinate is processed at latitude 43.2630 and longitude -2.9348
- **THEN** the spatial classifier determines that the point intersects the Bizkaia polygon and assigns the province code `"48"` (Bizkaia)

#### Scenario: Línea interprovincial que cruza territorios
- **WHEN** a route connects Bilbao (Bizkaia) and Donostia-San Sebastián (Gipuzkoa)
- **THEN** the route is linked to both Bizkaia and Gipuzkoa in `route_provinces` without duplicating the route record

---

### Requirement: Decodificación y enlace de datos en tiempo real (GTFS-RT)
The system SHALL decode GTFS-Realtime Protocol Buffers for Vehicle Positions, Trip Updates, and Service Alerts, associating them with the static GTFS network via `(operator_id, trip_id)` and `(operator_id, stop_id)`.

#### Scenario: Recepción de posición de vehículo de Metro Bilbao
- **WHEN** a GTFS-RT `VehiclePosition` message is received with vehicle ID `"503"` and trip ID `"892465"`
- **THEN** the system matches the vehicle to the active Metro Bilbao static trip and persists the real-time observation with timestamp and telemetry

---

### Requirement: Publicación segura mediante versiones de feed (Safe Version Switch)
The system SHALL stage new GTFS static imports in an isolated feed version, validate record counts and relationships, and execute an atomic version switch only upon complete validation pass.

#### Scenario: Fichero GTFS corrupto o incompleto
- **WHEN** a downloaded GTFS static archive fails ZIP integrity or referential validation
- **THEN** the ingestion job is marked as failed, the previous active feed version remains untouched in production, and an alert is recorded
