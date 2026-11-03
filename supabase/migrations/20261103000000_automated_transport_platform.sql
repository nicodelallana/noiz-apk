-- Migration: 20261103000000_automated_transport_platform.sql
-- Description: Automated Euskadi Public Transport Data Platform
-- Covers all 35 Moveuskadi operators, PostGIS spatial classification (Bizkaia, Gipuzkoa, Araba),
-- GTFS static tables with collision prevention namespaces, GTFS-RT, SIRI, NeTEx, and feed versioning.

-- ==============================================================================
-- 1. EXTENSIONS
-- ==============================================================================
create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- ==============================================================================
-- 2. GEOGRAPHY & ADMINISTRATIVE BOUNDARIES
-- ==============================================================================

create table if not exists public.provinces (
  code text primary key, -- '48' (Bizkaia), '20' (Gipuzkoa), '01' (Araba/Álava)
  name_es text not null,
  name_eu text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

insert into public.provinces (code, name_es, name_eu, slug)
values
  ('48', 'Bizkaia', 'Bizkaia', 'bizkaia'),
  ('20', 'Gipuzkoa', 'Gipuzkoa', 'gipuzkoa'),
  ('01', 'Álava', 'Araba', 'araba')
on conflict (code) do update set
  name_es = excluded.name_es,
  name_eu = excluded.name_eu,
  slug = excluded.slug;

create table if not exists public.administrative_boundaries (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('province', 'municipality', 'comarca')),
  code text not null,
  name text not null,
  province_code text references public.provinces(code) on delete cascade,
  geom geometry(MultiPolygon, 4326) not null,
  source text not null default 'GeoEuskadi',
  updated_at timestamptz not null default now()
);

create index if not exists idx_admin_boundaries_geom on public.administrative_boundaries using gist (geom);
create index if not exists idx_admin_boundaries_code on public.administrative_boundaries (code);

create table if not exists public.municipalities (
  code text primary key, -- INE code (e.g. 48020 for Bilbao)
  province_code text not null references public.provinces(code) on delete cascade,
  name_es text not null,
  name_eu text not null,
  geom geometry(MultiPolygon, 4326),
  created_at timestamptz not null default now()
);

create index if not exists idx_municipalities_geom on public.municipalities using gist (geom);

-- ==============================================================================
-- 3. OPERATORS & TRANSPORT MODES
-- ==============================================================================

create table if not exists public.transport_modes (
  id text primary key, -- 'bus', 'metro', 'train', 'tram', 'funicular', 'ferry', 'cable'
  name_es text not null,
  name_eu text not null,
  gtfs_route_type int not null,
  icon_name text not null default 'directions_bus',
  created_at timestamptz not null default now()
);

insert into public.transport_modes (id, name_es, name_eu, gtfs_route_type, icon_name)
values
  ('metro', 'Metro', 'Metroa', 1, 'subway'),
  ('train', 'Tren Cercanías / Regional', 'Trena', 2, 'train'),
  ('bus', 'Autobús Urbano / Interurbano', 'Autobusa', 3, 'directions_bus'),
  ('tram', 'Tranvía', 'Tranbia', 0, 'tram'),
  ('funicular', 'Funicular', 'Funikularra', 7, 'tram'),
  ('ferry', 'Transbordador / Barco', 'Transbordadorea', 4, 'directions_boat'),
  ('cable', 'Teleférico / Cable', 'Teleferikoa', 6, 'cable')
on conflict (id) do update set
  name_es = excluded.name_es,
  name_eu = excluded.name_eu,
  gtfs_route_type = excluded.gtfs_route_type,
  icon_name = excluded.icon_name;

create table if not exists public.transport_operators (
  id uuid primary key default gen_random_uuid(),
  original_name text not null unique,
  normalized_name text not null,
  slug text not null unique,
  is_active boolean not null default true,
  available_formats text[] not null default array[]::text[],
  primary_color text not nu# MASTER TECHNICAL SPECIFICATION — AUTOMATED EUSKADI PUBLIC TRANSPORT DATA PLATFORM
## Complete Moveuskadi Data Ingestion, Normalisation, Real-Time Processing and Supabase Integration

### 1. PROJECT OBJECTIVE

Build a complete, production-ready, fully automated public transport data ingestion and management system for the Basque Country (Euskadi), Spain.

The system must discover, download, process, validate, normalise, store and continuously update public transport data from all available operators and transport services across the three provinces:

- Bizkaia
- Gipuzkoa
- Araba / Álava

The platform will use Supabase (PostgreSQL + PostGIS + Storage) as its central database and storage infrastructure.

The system must integrate all available transport operators and transport modes published through the official Moveuskadi data catalogue.

**The most important requirement: the entire process must be automatic.**

Do not require manual ZIP downloads, manual operator selection, manually maintained download URLs or manual database imports.

The implementation must use the complete JSON index published by Open Data Euskadi / Moveuskadi as the primary source for discovering available data resources.

Do not build a solution around a single operator or a fixed GTFS download URL.

---

### 2. OFFICIAL DATA SOURCE — MOVEUSKADI

Primary catalogue:

https://www.moveuskadi.euskadi.eus/aa27aMovilidadWar/descargaMov

Official Open Data Euskadi dataset:

https://opendata.euskadi.eus/catalogo/-/moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-operadores-horarios-paradas-calendario-tarifas-etc/

The catalogue provides a complete JSON index containing operators, available formats, direct resource URLs, file names and last-update timestamps.

The JSON index must be treated as the authoritative resource catalogue.

### 2.1. JSON index structure

The index groups resources by operator.

An illustrative example:

```json
{
  "Errenteria": [
    {
      "format": "GTFS-RT",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "name": "gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "last-update": "2026-11-03 09:27:17"
    },
    {
      "format": "SIRI",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/siri_errenteriako urbanoa_situation_exchange.xml",
      "name": "siri_errenteriako urbanoa_situation_exchange.xml",
      "last-update": "2026-11-03 09:27:15"
    }
  ],
  "Metro Bilbao": [
    {
      "format": "GTFS",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfs_metro_bilbao.zip",
      "name": "gtfs_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:16"
    },
    {
      "format": "NETEX",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/netex_metro_bilbao.zip",
      "name": "netex_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:17"
    }
  ]
}
```

This is an example of the structure and not a complete list of resources.

The implementation must support the actual complete JSON document, including all operators and all resources it contains.

### 2.2. JSON index discovery

Implement a dedicated catalogue discovery service.

Requirements:

1. Automatically locate and retrieve the official complete JSON index.
2. Inspect the official catalogue page and its publicly accessible resources to identify the actual JSON index URL.
3. If the index URL is embedded in HTML or JavaScript, discover it programmatically.
4. Do not invent the JSON URL or assume an undocumented endpoint.
5. Store the discovered index URL in configuration.
6. Download the JSON index automatically on a configurable schedule.
7. Parse every operator and every resource.
8. Extract:
   - Operator name.
   - Format.
   - Direct download URL.
   - File name.
   - Last-update timestamp.
9. Preserve the original operator name and original metadata.
10. Support new operators appearing in future index updates without requiring code changes.
11. Detect operators that disappear from the index without immediately deleting their historical data.
12. Record every index retrieval, its timestamp, checksum and processing result.

The index must be dynamically parsed. Never hardcode individual operators or individual resource URLs.

### 2.3. URL handling

Use the exact URL provided by the JSON index.

Some file names and URLs may contain spaces or special characters. Handle URL encoding correctly without corrupting the original resource URL.

Do not construct URLs using operator names or file names when a direct URL is already provided.

Download resources using robust HTTP handling:

- Timeouts.
- Retry with exponential backoff.
- HTTP status validation.
- Content-length checks when available.
- Checksum calculation.
- Temporary files.
- Atomic promotion after successful validation.
- Logging of failed downloads.
- Support for large files.
- Appropriate User-Agent.
- Respect server rate limits and availability.

Never treat an HTTP error page as a valid ZIP, XML or Protocol Buffers resource.

---

### 3. SUPPORTED DATA FORMATS

The system must discover and process every format exposed by the index.

Implement separate ingestion modules for:

#### 3.1. GTFS Static

Expected resources commonly include ZIP archives containing:

- agency.txt
- stops.txt
- routes.txt
- trips.txt
- stop_times.txt
- calendar.txt
- calendar_dates.txt
- shapes.txt
- frequencies.txt
- transfers.txt
- pathways.txt
- levels.txt
- feed_info.txt
- attributions.txt

Not every feed will contain every file.

Requirements:

- Download automatically.
- Validate ZIP integrity.
- Inspect available files.
- Parse according to the GTFS specification.
- Validate references between agencies, stops, routes, trips and stop times.
- Preserve optional fields.
- Support feeds with different schemas and data quality.
- Normalise data into the common database model.
- Preserve original source records for traceability.

GTFS Static is the primary foundation for the transport network.

#### 3.2. GTFS-Realtime (GTFS-RT)

GTFS-RT resources may be individual Protocol Buffers files rather than ZIP archives.

Examples include:

- Vehicle Positions.
- Trip Updates.
- Service Alerts.

The JSON index may contain several GTFS-RT resources for the same operator.

The system must:

- Identify each GTFS-RT resource by its actual format and file name.
- Determine its message type where possible.
- Download and decode Protocol Buffers using the official GTFS-Realtime specification.
- Support vehicle position feeds.
- Support trip update feeds.
- Support service alert feeds.
- Validate feed headers and timestamps.
- Associate real-time records with their corresponding static GTFS entities whenever possible.
- Store observation timestamps and ingestion timestamps.
- Handle expired, missing or stale real-time information.
- Avoid duplicating observations unnecessarily.
- Maintain historical observations according to configurable retention policies.

Do not assume that every GTFS-RT URL returns a ZIP file.

Use the GTFS-Realtime Protocol Buffers definitions and a maintained compatible decoder.

If an operator publishes several real-time files, process each resource independently.

#### 3.3. SIRI

Support SIRI XML resources, including relevant SIRI service types such as:

- Situation Exchange.
- Estimated Timetable.
- Vehicle Monitoring.
- Stop Monitoring.
- Other supported SIRI services present in the published resources.

Requirements:

- Detect the actual SIRI message type.
- Parse XML safely.
- Support namespaces.
- Validate XML structure.
- Preserve timestamps and source identifiers.
- Normalise compatible data into the common transport model.
- Keep original XML files for traceability.
- Do not assume every SIRI resource has the same structure.

For example, a Situation Exchange XML resource must not be processed as if it were a GTFS static feed.

#### 3.4. NETEX

Support NeTEx resources, including ZIP archives and their XML contents.

Requirements:

- Detect archive type.
- Validate archive integrity.
- Extract XML safely.
- Support relevant NeTEx structures.
- Parse operators, networks, lines, routes, scheduled stops, timetables, service calendars and other supported entities.
- Preserve source identifiers and relationships.
- Map compatible entities to the common transport model.
- Maintain original source data.
- Handle large datasets and complex XML documents.

Do not assume that all NeTEx resources use the same packaging or XML structure.

#### 3.5. SHP

If SHP resources are available through the official catalogue or its FTP services, implement a separate spatial ingestion module.

Support:

- Shapefile.
- SHX.
- DBF.
- PRJ.
- Associated files.

Requirements:

- Validate that required components exist.
- Detect the original coordinate reference system.
- Convert geometries to the database's standard spatial reference system.
- Import compatible geometries into PostGIS.
- Associate spatial data with operators or routes when reliable identifiers exist.

Do not block the initial GTFS implementation while waiting for SHP integration.

---

### 4. OPERATOR DISCOVERY AND MANAGEMENT

Every operator in the JSON index must be discovered automatically.

Create a dynamic operator registry.

For each operator, store:

- Internal UUID.
- Original operator name.
- Normalised operator name.
- Slug.
- Active status.
- Available formats.
- Available resources.
- Last successful catalogue discovery.
- Last successful static import.
- Last successful real-time update.
- Source metadata.
- Assigned province or provinces, when known.
- Transport modes, when known.

Important:

An operator must not be assigned to a province solely because its name suggests a location.

Use reliable geographic evidence, such as stop coordinates, route geometry, official operator information or authoritative territorial boundaries.

Some operators may operate across more than one province. Support multiple province associations.

The same operator may publish GTFS, GTFS-RT, SIRI and NETEX resources simultaneously.

Treat each resource as a separate ingestion resource, while maintaining its relationship to the operator.

New operators and new formats must be discoverable without modifying the database schema or writing operator-specific ingestion code.

---

### 5. PROVINCIAL CLASSIFICATION — EUSKADI

The application must support three provinces:

1. Bizkaia.
2. Gipuzkoa.
3. Araba / Álava.

Create a province registry with stable internal identifiers.

Every stop must be geographically classified.

Use official administrative boundary geometries stored in PostGIS.

Recommended process:

1. Obtain authoritative provincial boundary polygons.
2. Store the polygons in PostGIS.
3. Validate and transform coordinate reference systems.
4. Read stop longitude and latitude.
5. Create geographic point geometries.
6. Determine which provincial polygon contains each stop.
7. Assign the corresponding province.
8. Record the classification method and confidence.
9. Flag stops that cannot be classified reliably.

Use spatial operations such as ST_Contains or ST_Intersects as appropriate.

Do not classify provinces using simple text matching or operator names.

### 5.1. Cross-provincial transport

Routes may cross provincial boundaries.

Therefore:

- A route may serve multiple provinces.
- A trip may cross provincial boundaries.
- An operator may serve multiple provinces.
- A stop belongs to the province determined by its geographical position.
- Route-province relationships must be derived from the geographical distribution of their stops or route geometry.

Create appropriate many-to-many relationships.

The application must support queries such as:

- All stops in Bizkaia.
- All routes serving Gipuzkoa.
- All operators serving Araba.
- Routes connecting Bizkaia and Gipuzkoa.
- All transport services within a province.
- Stops and routes near a given coordinate.

Do not duplicate a route merely because it crosses provincial boundaries.

---

### 6. CENTRAL SUPABASE DATABASE

Use one central Supabase project and one consistent data model for the whole Basque Country.

Enable PostGIS.

Use UUID primary keys for internal records.

Keep external identifiers as source identifiers, not as globally unique database primary keys.

### 6.1. Recommended core tables

Create a properly normalised relational schema, including:

**Geography and classification**

- provinces
- municipalities
- administrative_boundaries
- stop_provinces
- route_provinces

**Operators and sources**

- transport_operators
- transport_modes
- operator_transport_modes
- operator_provinces
- gtfs_sources
- source_resources
- source_resource_formats

**Catalogue and ingestion**

- catalogue_snapshots
- catalogue_resources
- ingestion_jobs
- ingestion_job_logs
- ingestion_errors
- feed_versions
- feed_files
- resource_checksums

**GTFS Static**

- agencies
- stops
- routes
- trips
- stop_times
- calendars
- calendar_dates
- shapes
- frequencies
- transfers
- pathways
- levels
- feed_info
- attributions

**Real-time**

- realtime_feed_snapshots
- vehicle_positions
- trip_updates
- stop_time_updates
- service_alerts
- alert_informed_entities
- realtime_observations

**Other formats**

- siri_messages
- siri_vehicle_observations
- siri_situation_exchanges
- netex_resources
- netex_lines
- netex_stops
- netex_routes
- netex_services
- spatial_resources

Adapt the final schema to the actual contents of the available feeds.

Do not create unnecessary duplicate tables if a well-designed shared model is more appropriate.

### 6.2. Identifier collision prevention

GTFS identifiers are not guaranteed to be globally unique.

Never assume that two operators use different stop IDs, route IDs or trip IDs.

Implement a source namespace.

For example:

- source_id
- source_operator_id
- external_stop_id
- external_route_id
- external_trip_id

Use unique constraints based on the source namespace and external identifier.

This must prevent collisions between operators.

Maintain mappings between original identifiers and internal UUIDs.

Do not overwrite one operator's data with another operator's data.

### 6.3. Historical versions

Maintain feed versions.

Each successful import must record:

- Operator.
- Resource.
- Format.
- Source URL.
- Catalogue timestamp.
- Download timestamp.
- Checksum.
- File size.
- Import start and end times.
- Number of processed records.
- Number of rejected records.
- Validation status.
- Software/parser version.

Preserve historical feed versions when useful for auditing and comparison.

---

### 7. AUTOMATED INGESTION ARCHITECTURE

Build a modular ingestion pipeline.

Recommended architecture:

**A. Catalogue discovery service**

- Retrieves the official JSON index.
- Detects all operators and resources.
- Compares the new index with the previous snapshot.
- Detects new resources, removed resources and updated resources.
- Creates ingestion jobs.

**B. Download service**

- Downloads resources using the exact URLs in the index.
- Supports concurrent downloads with configurable limits.
- Implements retries and backoff.
- Verifies files.
- Calculates checksums.
- Stores raw files in Supabase Storage.

**C. Format detection and routing**

Routes each resource to the correct processor based on the actual catalogue format and validated file characteristics.

Do not process every resource as GTFS.

**D. Processing services**

Independent processors for:

- GTFS Static.
- GTFS-Realtime.
- SIRI.
- NETEX.
- SHP.

**E. Normalisation service**

Maps compatible data to the common Supabase schema.

**F. Spatial classification service**

Assigns stops, routes and operators to the appropriate provinces where supported by reliable evidence.

**G. Validation service**

Runs structural, relational and geographical checks.

**H. Publication service**

Publishes successfully validated data into production tables.

Use staging tables and atomic transactions where possible.

**I. Monitoring service**

Records processing status, errors, metrics and last successful updates.

### 7.1. Safe publication

Never destroy valid production data because a new download or import fails.

Use the following approach:

1. Download to temporary storage.
2. Validate the resource.
3. Import into staging tables or a new feed version.
4. Check record counts and relationships.
5. Run validation.
6. Publish the new version transactionally or through a controlled version switch.
7. Retain the previous working version until the new version is confirmed.

Failed imports must not leave partially updated production data.

---

### 8. AUTOMATIC UPDATE SCHEDULE

Implement configurable update schedules.

Suggested initial defaults:

| Process | Suggested frequency |
|---|---|
| JSON catalogue discovery | Every 15 minutes |
| GTFS Static change detection | Every 6 hours |
| Changed GTFS Static downloads | When catalogue metadata or checksum indicates a change |
| GTFS-RT Vehicle Positions | Every 15–30 seconds, subject to source limits |
| GTFS-RT Trip Updates | Every 30–60 seconds, subject to source limits |
| GTFS-RT Service Alerts | Every 1–5 minutes, subject to source limits |
| SIRI | According to source update frequency |
| NETEX | When the source resource changes |
| SHP | When the source resource changes |

These are configurable starting values, not guaranteed publication frequencies.

Use the index's `last-update` timestamp to detect potential changes.

However, do not rely exclusively on that timestamp.

Use checksums, HTTP metadata and source validation where appropriate.

Do not repeatedly download unchanged large resources unnecessarily.

For real-time feeds, do not assume that a file timestamp accurately represents the freshness of the actual observations.

Store both source timestamps and ingestion timestamps.

---

### 9. SUPABASE STORAGE

Create a structured Storage organisation.

Example:

```text
moveuskadi/
  catalogue/
    snapshots/
  raw/
    bizkaia/
    gipuzkoa/
    araba/
    unclassified/
  processed/
    gtfs/
    gtfsrt/
    siri/
    netex/
    shp/
  failed/
    downloads/
    processing/
  archives/
    historical/
```

The exact folder organisation may be improved during implementation.

Requirements:

- Store raw original resources.
- Store the original JSON index snapshots.
- Preserve downloaded files for auditability.
- Use versioned file paths.
- Avoid overwriting the only copy of a previous resource.
- Apply retention policies.
- Restrict access to internal ingestion files.
- Do not expose service-role credentials to frontend code.

If a resource cannot be confidently assigned to one province, keep it in an unclassified or shared area until classification is established.

---

### 10. GTFS STATIC AND REAL-TIME ASSOCIATION

A critical requirement is connecting real-time information to the correct static transport network.

Implement matching using:

- Operator/source namespace.
- Feed identifiers.
- Route IDs.
- Trip IDs.
- Stop IDs.
- Vehicle IDs.
- Service dates.
- Start times.
- Source-provided references.

Do not assume an ID in one operator's GTFS-RT feed belongs to another operator.

When an association cannot be established:

- Preserve the original real-time record.
- Mark the association as unresolved.
- Do not invent a route, stop or trip.
- Allow subsequent matching when static data becomes available.

Vehicle positions should support:

- Latitude.
- Longitude.
- Bearing.
- Speed.
- Vehicle identifier.
- Trip reference.
- Route reference.
- Timestamp.
- Source operator.
- Source resource.

Trip updates should support:

- Trip reference.
- Route reference.
- Stop sequence.
- Stop reference.
- Arrival and departure predictions.
- Delays.
- Relationship to the scheduled service.

Service alerts should support:

- Header and description translations.
- Active periods.
- Cause and effect.
- Informed entities.
- Affected routes, trips and stops.

Implement historical retention and deduplication strategies to avoid uncontrolled database growth.

---

### 11. TRANSPORT MODES

The platform must support all relevant transport modes published through Moveuskadi, including where available:

- Urban buses.
- Interurban buses.
- Regional buses.
- Metro.
- Tram.
- Commuter rail.
- Regional rail.
- Funiculars.
- Cable or other special transport services.
- Ferries and other water transport.
- Other public transport services represented in the catalogue.

Do not hardcode the list of operators or assume that every transport mode is present in every province.

Create a flexible transport-mode registry.

An operator may provide multiple modes.

A route must have an associated mode where the source provides enough information to determine it reliably.

---

### 12. VALIDATION AND DATA QUALITY

Implement comprehensive validation.

**Catalogue validation**

- Valid JSON.
- Expected operator/resource structure.
- Required fields.
- Valid resource URLs.
- Valid timestamps.
- Duplicate resource detection.

**Download validation**

- HTTP success.
- Correct content.
- Non-empty files.
- Correct file signatures.
- ZIP integrity.
- XML parseability.
- Protocol Buffers decoding.

**GTFS validation**

- Required files.
- Correct headers.
- Valid field types.
- Referential integrity.
- Valid stop coordinates.
- Valid route and trip relationships.
- Valid service calendars.
- Valid stop-time relationships.

**Spatial validation**

- Valid coordinates.
- Geographic range checks.
- Coordinate reference system checks.
- Province classification.
- Geometry validity.

**Real-time validation**

- Valid feed header.
- Freshness checks.
- Valid timestamps.
- Correct message types.
- Static entity matching.
- Duplicate observation detection.

Create a validation report for each ingestion job.

Do not silently discard invalid records.

Keep rejection reasons and relevant source information.

---

### 13. API AND FRONTEND INTEGRATION

Expose a clean and efficient data access layer for the application.

The frontend should be able to retrieve:

- Provinces.
- Municipalities.
- Operators.
- Transport modes.
- Stops.
- Routes.
- Trips.
- Timetables.
- Service calendars.
- Real-time vehicle positions.
- Real-time delays.
- Service alerts.
- Route geometries.

Support filtering by:

- Province.
- Municipality.
- Operator.
- Transport mode.
- Route.
- Stop.
- Geographic area.

Use PostGIS for geographic queries.

Create appropriate indexes for:

- Province identifiers.
- Operator identifiers.
- External identifiers.
- Route identifiers.
- Stop identifiers.
- Geometry columns.
- Observation timestamps.

Use Supabase Row Level Security for all exposed tables.

Keep ingestion operations on trusted server-side infrastructure.

Never expose Supabase service-role keys in the frontend.

---

### 14. TECHNOLOGY AND IMPLEMENTATION REQUIREMENTS

Use a robust, maintainable architecture.

Recommended technologies:

- Supabase PostgreSQL.
- PostGIS.
- Supabase Storage.
- Python for ingestion and ETL.
- FastAPI if an internal API or ingestion service is needed.
- Official GTFS and GTFS-Realtime specifications.
- Reliable XML processing libraries for SIRI and NeTEx.
- A maintained Protocol Buffers implementation.
- Docker for reproducible deployment.
- A scheduler such as cron, APScheduler or an appropriate job orchestration solution.

Use Supabase Edge Functions only for lightweight operations.

Do not attempt to process very large ZIP archives, complex NeTEx datasets or high-volume real-time ingestion entirely inside Edge Functions.

Use an external worker or containerised Python service for heavy processing.

Use Supabase migrations to manage schema changes.

Store all secrets in environment variables or an appropriate secrets manager.

Provide `.env.example` without real credentials.

---

### 15. AUTOMATION, LOGGING AND MONITORING

Build an administrative monitoring system.

For each operator, display:

- Name.
- Available formats.
- Number of discovered resources.
- Last catalogue update.
- Last successful download.
- Last successful static import.
- Last real-time update.
- Current ingestion status.
- Validation status.
- Error count.

For the whole platform, display:

- Number of discovered operators.
- Number of active resources.
- Number of GTFS feeds.
- Number of GTFS-RT feeds.
- Number of SIRI resources.
- Number of NETEX resources.
- Number of stops.
- Number of routes.
- Number of trips.
- Number of real-time observations.
- Number of failed jobs.
- Last successful catalogue scan.

Implement structured logs and error categorisation.

Send alerts for:

- Catalogue retrieval failures.
- Repeated download failures.
- Invalid resources.
- Failed imports.
- Stale real-time feeds.
- Unexpectedly large record-count changes.
- Missing operators or resources.

Provide retry mechanisms for failed jobs.

Do not require an administrator to manually restart the entire ingestion process.

---

### 16. SECURITY AND RELIABILITY

Implement:

- Supabase Row Level Security.
- Server-side service-role access only.
- Secure secrets management.
- Download size limits.
- Request timeouts.
- Retry limits.
- ZIP extraction safeguards against path traversal.
- XML protections against XXE and unsafe external entity resolution.
- Safe file handling.
- Database transaction management.
- Rate limiting.
- Input validation.
- Audit logs.

Treat all external resources as untrusted input.

Do not execute downloaded files.

Do not trust file extensions as proof of file type.

Validate actual content before processing.

---

### 17. TESTING REQUIREMENTS

Create automated tests for the entire pipeline.

Include:

1. JSON index discovery.
2. Parsing multiple operators.
3. Parsing multiple resources per operator.
4. Handling missing optional fields.
5. Handling spaces and special characters in URLs.
6. Detecting new operators.
7. Detecting new resources.
8. Detecting changed resources.
9. Downloading GTFS ZIP files.
10. Decoding GTFS-RT Protocol Buffers.
11. Parsing SIRI XML.
12. Parsing NeTEx archives.
13. Handling SHP resources.
14. Preventing cross-operator ID collisions.
15. Assigning stops to the correct province.
16. Handling cross-provincial routes.
17. Handling failed downloads.
18. Handling invalid ZIP files.
19. Handling malformed XML.
20. Handling stale real-time feeds.
21. Preventing duplicate imports.
22. Preserving previous production data after failed imports.
23. Running the pipeline repeatedly without creating duplicate records.

Use representative resources from different operators and formats.

Include unit tests, integration tests and end-to-end tests.

---

### 18. IMPLEMENTATION PHASES

Implement the project in controlled phases.

**Phase 1 — Catalogue discovery**

- Identify the real complete JSON index URL.
- Build the automatic index downloader.
- Parse every operator and resource.
- Save catalogue snapshots.
- Create the operator and resource registry.

**Phase 2 — GTFS Static ingestion**

- Download all GTFS resources.
- Validate ZIP files.
- Parse GTFS.
- Build the central relational model.
- Import stops, routes, trips, calendars and timetables.
- Implement source namespaces.

**Phase 3 — Provincial classification**

- Import official provincial boundaries.
- Enable PostGIS.
- Geographically classify stops.
- Build route-province relationships.
- Handle shared and cross-provincial services.

**Phase 4 — GTFS-Realtime**

- Discover all GTFS-RT resources.
- Identify Vehicle Positions, Trip Updates and Service Alerts.
- Decode Protocol Buffers.
- Associate real-time records with static feeds.
- Implement frequent updates and retention.

**Phase 5 — SIRI**

- Discover and parse SIRI resources.
- Implement the supported message types.
- Normalise compatible data.

**Phase 6 — NeTEx**

- Download and inspect NeTEx resources.
- Implement XML and archive processing.
- Normalise compatible entities.

**Phase 7 — SHP**

- Discover available SHP resources.
- Import spatial datasets.
- Connect relevant geometries with transport entities.

**Phase 8 — Production automation**

- Configure schedules.
- Implement monitoring.
- Add alerts.
- Add retry mechanisms.
- Optimise database queries.
- Complete security and performance testing.

Do not mark a phase as complete until its acceptance criteria are met.

---

### 19. REQUIRED PROJECT DELIVERABLES

Provide:

1. Complete architecture documentation.
2. Supabase SQL migrations.
3. PostGIS configuration.
4. Python ingestion project.
5. JSON catalogue discovery module.
6. Automatic resource download manager.
7. GTFS Static processor.
8. GTFS-Realtime processor.
9. SIRI processor.
10. NeTEx processor.
11. SHP processor or documented implementation plan if source availability prevents immediate completion.
12. Provincial classification module.
13. Supabase Storage integration.
14. Automated scheduling configuration.
15. Monitoring and logging.
16. Validation and error reports.
17. Automated tests.
18. Docker configuration.
19. `.env.example`.
20. Deployment instructions.
21. Documentation explaining how to add new formats and processors.
22. Documentation explaining how to recover from failed ingestion jobs.

Provide working code, not just architectural suggestions.

Do not leave core functionality as pseudocode, TODO comments or manual procedures.

If a particular format cannot be implemented because the source documentation or resource is unavailable, clearly document the limitation and implement the rest of the system.

---

### 20. ACCEPTANCE CRITERIA

The implementation is considered successful only when all of the following are true:

- The system automatically retrieves the complete official JSON index.
- It discovers every operator present in that index.
- It discovers every resource published for each operator.
- It reads the exact direct download URL from each resource entry.
- It supports resources with spaces and special characters in their URLs.
- It detects the format of each resource correctly.
- It downloads GTFS Static automatically.
- It decodes GTFS-Realtime resources correctly.
- It processes SIRI resources using the appropriate XML parser.
- It processes NeTEx resources using the appropriate parser.
- It can process SHP resources when available.
- It stores original files in Supabase Storage.
- It imports normalised data into Supabase PostgreSQL.
- It prevents identifier collisions between operators.
- It classifies stops geographically into Bizkaia, Gipuzkoa and Araba.
- It supports routes and operators that serve multiple provinces.
- It updates changed resources automatically.
- It does not unnecessarily download unchanged static resources.
- It preserves valid production data when an import fails.
- It records ingestion history, checksums and errors.
- It supports real-time transport information.
- It can discover new operators and resources without code changes.
- It runs automatically without manual ZIP downloads or manual operator selection.

---

### 21. IMPORTANT DEVELOPMENT INSTRUCTIONS

Before writing the final implementation:

1. Inspect the existing application, repository, database and Supabase configuration.
2. Reuse existing working components where appropriate.
3. Identify the actual official JSON index endpoint from the Moveuskadi catalogue.
4. Inspect real index entries and representative resources from different operators.
5. Verify the actual file structures and formats.
6. Confirm which resources are static and which are real-time.
7. Design the database around the actual data rather than assumptions.
8. Implement the ingestion pipeline incrementally.
9. Run tests against real representative resources.
10. Document any source limitations.

**Do not fabricate endpoints, operator names, resource URLs, transport data or successful import results.**

**Do not use a manually maintained list of operators.**

**Do not hardcode download URLs when the JSON index already provides them.**

**Do not assume that every resource is a ZIP file.**

**Do not treat GTFS-RT, SIRI and NeTEx as GTFS Static.**

**Do not classify an entire operator into one province without geographical evidence.**

**Do not overwrite valid production data with incomplete or failed imports.**
# MASTER TECHNICAL SPECIFICATION — AUTOMATED EUSKADI PUBLIC TRANSPORT DATA PLATFORM
## Complete Moveuskadi Data Ingestion, Normalisation, Real-Time Processing and Supabase Integration

### 1. PROJECT OBJECTIVE

Build a complete, production-ready, fully automated public transport data ingestion and management system for the Basque Country (Euskadi), Spain.

The system must discover, download, process, validate, normalise, store and continuously update public transport data from all available operators and transport services across the three provinces:

- Bizkaia
- Gipuzkoa
- Araba / Álava

The platform will use Supabase (PostgreSQL + PostGIS + Storage) as its central database and storage infrastructure.

The system must integrate all available transport operators and transport modes published through the official Moveuskadi data catalogue.

**The most important requirement: the entire process must be automatic.**

Do not require manual ZIP downloads, manual operator selection, manually maintained download URLs or manual database imports.

The implementation must use the complete JSON index published by Open Data Euskadi / Moveuskadi as the primary source for discovering available data resources.

Do not build a solution around a single operator or a fixed GTFS download URL.

---

### 2. OFFICIAL DATA SOURCE — MOVEUSKADI

Primary catalogue:

https://www.moveuskadi.euskadi.eus/aa27aMovilidadWar/descargaMov

Official Open Data Euskadi dataset:

https://opendata.euskadi.eus/catalogo/-/moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-operadores-horarios-paradas-calendario-tarifas-etc/

The catalogue provides a complete JSON index containing operators, available formats, direct resource URLs, file names and last-update timestamps.

The JSON index must be treated as the authoritative resource catalogue.

### 2.1. JSON index structure

The index groups resources by operator.

An illustrative example:

```json
{
  "Errenteria": [
    {
      "format": "GTFS-RT",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "name": "gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "last-update": "2026-11-03 09:27:17"
    },
    {
      "format": "SIRI",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/siri_errenteriako urbanoa_situation_exchange.xml",
      "name": "siri_errenteriako urbanoa_situation_exchange.xml",
      "last-update": "2026-11-03 09:27:15"
    }
  ],
  "Metro Bilbao": [
    {
      "format": "GTFS",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfs_metro_bilbao.zip",
      "name": "gtfs_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:16"
    },
    {
      "format": "NETEX",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/netex_metro_bilbao.zip",
      "name": "netex_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:17"
    }
  ]
}
```

This is an example of the structure and not a complete list of resources.

The implementation must support the actual complete JSON document, including all operators and all resources it contains.

### 2.2. JSON index discovery

Implement a dedicated catalogue discovery service.

Requirements:

1. Automatically locate and retrieve the official complete JSON index.
2. Inspect the official catalogue page and its publicly accessible resources to identify the actual JSON index URL.
3. If the index URL is embedded in HTML or JavaScript, discover it programmatically.
4. Do not invent the JSON URL or assume an undocumented endpoint.
5. Store the discovered index URL in configuration.
6. Download the JSON index automatically on a configurable schedule.
7. Parse every operator and every resource.
8. Extract:
   - Operator name.
   - Format.
   - Direct download URL.
   - File name.
   - Last-update timestamp.
9. Preserve the original operator name and original metadata.
10. Support new operators appearing in future index updates without requiring code changes.
11. Detect operators that disappear from the index without immediately deleting their historical data.
12. Record every index retrieval, its timestamp, checksum and processing result.

The index must be dynamically parsed. Never hardcode individual operators or individual resource URLs.

### 2.3. URL handling

Use the exact URL provided by the JSON index.

Some file names and URLs may contain spaces or special characters. Handle URL encoding correctly without corrupting the original resource URL.

Do not construct URLs using operator names or file names when a direct URL is already provided.

Download resources using robust HTTP handling:

- Timeouts.
- Retry with exponential backoff.
- HTTP status validation.
- Content-length checks when available.
- Checksum calculation.
- Temporary files.
- Atomic promotion after successful validation.
- Logging of failed downloads.
- Support for large files.
- Appropriate User-Agent.
- Respect server rate limits and availability.

Never treat an HTTP error page as a valid ZIP, XML or Protocol Buffers resource.

---

### 3. SUPPORTED DATA FORMATS

The system must discover and process every format exposed by the index.

Implement separate ingestion modules for:

#### 3.1. GTFS Static

Expected resources commonly include ZIP archives containing:

- agency.txt
- stops.txt
- routes.txt
- trips.txt
- stop_times.txt
- calendar.txt
- calendar_dates.txt
- shapes.txt
- frequencies.txt
- transfers.txt
- pathways.txt
- levels.txt
- feed_info.txt
- attributions.txt

Not every feed will contain every file.

Requirements:

- Download automatically.
- Validate ZIP integrity.
- Inspect available files.
- Parse according to the GTFS specification.
- Validate references between agencies, stops, routes, trips and stop times.
- Preserve optional fields.
- Support feeds with different schemas and data quality.
- Normalise data into the common database model.
- Preserve original source records for traceability.

GTFS Static is the primary foundation for the transport network.

#### 3.2. GTFS-Realtime (GTFS-RT)

GTFS-RT resources may be individual Protocol Buffers files rather than ZIP archives.

Examples include:

- Vehicle Positions.
- Trip Updates.
- Service Alerts.

The JSON index may contain several GTFS-RT resources for the same operator.

The system must:

- Identify each GTFS-RT resource by its actual format and file name.
- Determine its message type where possible.
- Download and decode Protocol Buffers using the official GTFS-Realtime specification.
- Support vehicle position feeds.
- Support trip update feeds.
- Support service alert feeds.
- Validate feed headers and timestamps.
- Associate real-time records with their corresponding static GTFS entities whenever possible.
- Store observation timestamps and ingestion timestamps.
- Handle expired, missing or stale real-time information.
- Avoid duplicating observations unnecessarily.
- Maintain historical observations according to configurable retention policies.

Do not assume that every GTFS-RT URL returns a ZIP file.

Use the GTFS-Realtime Protocol Buffers definitions and a maintained compatible decoder.

If an operator publishes several real-time files, process each resource independently.

#### 3.3. SIRI

Support SIRI XML resources, including relevant SIRI service types such as:

- Situation Exchange.
- Estimated Timetable.
- Vehicle Monitoring.
- Stop Monitoring.
- Other supported SIRI services present in the published resources.

Requirements:

- Detect the actual SIRI message type.
- Parse XML safely.
- Support namespaces.
- Validate XML structure.
- Preserve timestamps and source identifiers.
- Normalise compatible data into the common transport model.
- Keep original XML files for traceability.
- Do not assume every SIRI resource has the same structure.

For example, a Situation Exchange XML resource must not be processed as if it were a GTFS static feed.

#### 3.4. NETEX

Support NeTEx resources, including ZIP archives and their XML contents.

Requirements:

- Detect archive type.
- Validate archive integrity.
- Extract XML safely.
- Support relevant NeTEx structures.
- Parse operators, networks, lines, routes, scheduled stops, timetables, service calendars and other supported entities.
- Preserve source identifiers and relationships.
- Map compatible entities to the common transport model.
- Maintain original source data.
- Handle large datasets and complex XML documents.

Do not assume that all NeTEx resources use the same packaging or XML structure.

#### 3.5. SHP

If SHP resources are available through the official catalogue or its FTP services, implement a separate spatial ingestion module.

Support:

- Shapefile.
- SHX.
- DBF.
- PRJ.
- Associated files.

Requirements:

- Validate that required components exist.
- Detect the original coordinate reference system.
- Convert geometries to the database's standard spatial reference system.
- Import compatible geometries into PostGIS.
- Associate spatial data with operators or routes when reliable identifiers exist.

Do not block the initial GTFS implementation while waiting for SHP integration.

---

### 4. OPERATOR DISCOVERY AND MANAGEMENT

Every operator in the JSON index must be discovered automatically.

Create a dynamic operator registry.

For each operator, store:

- Internal UUID.
- Original operator name.
- Normalised operator name.
- Slug.
- Active status.
- Available formats.
- Available resources.
- Last successful catalogue discovery.
- Last successful static import.
- Last successful real-time update.
- Source metadata.
- Assigned province or provinces, when known.
- Transport modes, when known.

Important:

An operator must not be assigned to a province solely because its name suggests a location.

Use reliable geographic evidence, such as stop coordinates, route geometry, official operator information or authoritative territorial boundaries.

Some operators may operate across more than one province. Support multiple province associations.

The same operator may publish GTFS, GTFS-RT, SIRI and NETEX resources simultaneously.

Treat each resource as a separate ingestion resource, while maintaining its relationship to the operator.

New operators and new formats must be discoverable without modifying the database schema or writing operator-specific ingestion code.

---

### 5. PROVINCIAL CLASSIFICATION — EUSKADI

The application must support three provinces:

1. Bizkaia.
2. Gipuzkoa.
3. Araba / Álava.

Create a province registry with stable internal identifiers.

Every stop must be geographically classified.

Use official administrative boundary geometries stored in PostGIS.

Recommended process:

1. Obtain authoritative provincial boundary polygons.
2. Store the polygons in PostGIS.
3. Validate and transform coordinate reference systems.
4. Read stop longitude and latitude.
5. Create geographic point geometries.
6. Determine which provincial polygon contains each stop.
7. Assign the corresponding province.
8. Record the classification method and confidence.
9. Flag stops that cannot be classified reliably.

Use spatial operations such as ST_Contains or ST_Intersects as appropriate.

Do not classify provinces using simple text matching or operator names.

### 5.1. Cross-provincial transport

Routes may cross provincial boundaries.

Therefore:

- A route may serve multiple provinces.
- A trip may cross provincial boundaries.
- An operator may serve multiple provinces.
- A stop belongs to the province determined by its geographical position.
- Route-province relationships must be derived from the geographical distribution of their stops or route geometry.

Create appropriate many-to-many relationships.

The application must support queries such as:

- All stops in Bizkaia.
- All routes serving Gipuzkoa.
- All operators serving Araba.
- Routes connecting Bizkaia and Gipuzkoa.
- All transport services within a province.
- Stops and routes near a given coordinate.

Do not duplicate a route merely because it crosses provincial boundaries.

---

### 6. CENTRAL SUPABASE DATABASE

Use one central Supabase project and one consistent data model for the whole Basque Country.

Enable PostGIS.

Use UUID primary keys for internal records.

Keep external identifiers as source identifiers, not as globally unique database primary keys.

### 6.1. Recommended core tables

Create a properly normalised relational schema, including:

**Geography and classification**

- provinces
- municipalities
- administrative_boundaries
- stop_provinces
- route_provinces

**Operators and sources**

- transport_operators
- transport_modes
- operator_transport_modes
- operator_provinces
- gtfs_sources
- source_resources
- source_resource_formats

**Catalogue and ingestion**

- catalogue_snapshots
- catalogue_resources
- ingestion_jobs
- ingestion_job_logs
- ingestion_errors
- feed_versions
- feed_files
- resource_checksums

**GTFS Static**

- agencies
- stops
- routes
- trips
- stop_times
- calendars
- calendar_dates
- shapes
- frequencies
- transfers
- pathways
- levels
- feed_info
- attributions

**Real-time**

- realtime_feed_snapshots
- vehicle_positions
- trip_updates
- stop_time_updates
- service_alerts
- alert_informed_entities
- realtime_observations

**Other formats**

- siri_messages
- siri_vehicle_observations
- siri_situation_exchanges
- netex_resources
- netex_lines
- netex_stops
- netex_routes
- netex_services
- spatial_resources

Adapt the final schema to the actual contents of the available feeds.

Do not create unnecessary duplicate tables if a well-designed shared model is more appropriate.

### 6.2. Identifier collision prevention

GTFS identifiers are not guaranteed to be globally unique.

Never assume that two operators use different stop IDs, route IDs or trip IDs.

Implement a source namespace.

For example:

- source_id
- source_operator_id
- external_stop_id
- external_route_id
- external_trip_id

Use unique constraints based on the source namespace and external identifier.

This must prevent collisions between operators.

Maintain mappings between original identifiers and internal UUIDs.

Do not overwrite one operator's data with another operator's data.

### 6.3. Historical versions

Maintain feed versions.

Each successful import must record:

- Operator.
- Resource.
- Format.
- Source URL.
- Catalogue timestamp.
- Download timestamp.
- Checksum.
- File size.
- Import start and end times.
- Number of processed records.
- Number of rejected records.
- Validation status.
- Software/parser version.

Preserve historical feed versions when useful for auditing and comparison.

---

### 7. AUTOMATED INGESTION ARCHITECTURE

Build a modular ingestion pipeline.

Recommended architecture:

**A. Catalogue discovery service**

- Retrieves the official JSON index.
- Detects all operators and resources.
- Compares the new index with the previous snapshot.
- Detects new resources, removed resources and updated resources.
- Creates ingestion jobs.

**B. Download service**

- Downloads resources using the exact URLs in the index.
- Supports concurrent downloads with configurable limits.
- Implements retries and backoff.
- Verifies files.
- Calculates checksums.
- Stores raw files in Supabase Storage.

**C. Format detection and routing**

Routes each resource to the correct processor based on the actual catalogue format and validated file characteristics.

Do not process every resource as GTFS.

**D. Processing services**

Independent processors for:

- GTFS Static.
- GTFS-Realtime.
- SIRI.
- NETEX.
- SHP.

**E. Normalisation service**

Maps compatible data to the common Supabase schema.

**F. Spatial classification service**

Assigns stops, routes and operators to the appropriate provinces where supported by reliable evidence.

**G. Validation service**

Runs structural, relational and geographical checks.

**H. Publication service**

Publishes successfully validated data into production tables.

Use staging tables and atomic transactions where possible.

**I. Monitoring service**

Records processing status, errors, metrics and last successful updates.

### 7.1. Safe publication

Never destroy valid production data because a new download or import fails.

Use the following approach:

1. Download to temporary storage.
2. Validate the resource.
3. Import into staging tables or a new feed version.
4. Check record counts and relationships.
5. Run validation.
6. Publish the new version transactionally or through a controlled version switch.
7. Retain the previous working version until the new version is confirmed.

Failed imports must not leave partially updated production data.

---

### 8. AUTOMATIC UPDATE SCHEDULE

Implement configurable update schedules.

Suggested initial defaults:

| Process | Suggested frequency |
|---|---|
| JSON catalogue discovery | Every 15 minutes |
| GTFS Static change detection | Every 6 hours |
| Changed GTFS Static downloads | When catalogue metadata or checksum indicates a change |
| GTFS-RT Vehicle Positions | Every 15–30 seconds, subject to source limits |
| GTFS-RT Trip Updates | Every 30–60 seconds, subject to source limits |
| GTFS-RT Service Alerts | Every 1–5 minutes, subject to source limits |
| SIRI | According to source update frequency |
| NETEX | When the source resource changes |
| SHP | When the source resource changes |

These are configurable starting values, not guaranteed publication frequencies.

Use the index's `last-update` timestamp to detect potential changes.

However, do not rely exclusively on that timestamp.

Use checksums, HTTP metadata and source validation where appropriate.

Do not repeatedly download unchanged large resources unnecessarily.

For real-time feeds, do not assume that a file timestamp accurately represents the freshness of the actual observations.

Store both source timestamps and ingestion timestamps.

---

### 9. SUPABASE STORAGE

Create a structured Storage organisation.

Example:

```text
moveuskadi/
  catalogue/
    snapshots/
  raw/
    bizkaia/
    gipuzkoa/
    araba/
    unclassified/
  processed/
    gtfs/
    gtfsrt/
    siri/
    netex/
    shp/
  failed/
    downloads/
    processing/
  archives/
    historical/
```

The exact folder organisation may be improved during implementation.

Requirements:

- Store raw original resources.
- Store the original JSON index snapshots.
- Preserve downloaded files for auditability.
- Use versioned file paths.
- Avoid overwriting the only copy of a previous resource.
- Apply retention policies.
- Restrict access to internal ingestion files.
- Do not expose service-role credentials to frontend code.

If a resource cannot be confidently assigned to one province, keep it in an unclassified or shared area until classification is established.

---

### 10. GTFS STATIC AND REAL-TIME ASSOCIATION

A critical requirement is connecting real-time information to the correct static transport network.

Implement matching using:

- Operator/source namespace.
- Feed identifiers.
- Route IDs.
- Trip IDs.
- Stop IDs.
- Vehicle IDs.
- Service dates.
- Start times.
- Source-provided references.

Do not assume an ID in one operator's GTFS-RT feed belongs to another operator.

When an association cannot be established:

- Preserve the original real-time record.
- Mark the association as unresolved.
- Do not invent a route, stop or trip.
- Allow subsequent matching when static data becomes available.

Vehicle positions should support:

- Latitude.
- Longitude.
- Bearing.
- Speed.
- Vehicle identifier.
- Trip reference.
- Route reference.
- Timestamp.
- Source operator.
- Source resource.

Trip updates should support:

- Trip reference.
- Route reference.
- Stop sequence.
- Stop reference.
- Arrival and departure predictions.
- Delays.
- Relationship to the scheduled service.

Service alerts should support:

- Header and description translations.
- Active periods.
- Cause and effect.
- Informed entities.
- Affected routes, trips and stops.

Implement historical retention and deduplication strategies to avoid uncontrolled database growth.

---

### 11. TRANSPORT MODES

The platform must support all relevant transport modes published through Moveuskadi, including where available:

- Urban buses.
- Interurban buses.
- Regional buses.
- Metro.
- Tram.
- Commuter rail.
- Regional rail.
- Funiculars.
- Cable or other special transport services.
- Ferries and other water transport.
- Other public transport services represented in the catalogue.

Do not hardcode the list of operators or assume that every transport mode is present in every province.

Create a flexible transport-mode registry.

An operator may provide multiple modes.

A route must have an associated mode where the source provides enough information to determine it reliably.

---

### 12. VALIDATION AND DATA QUALITY

Implement comprehensive validation.

**Catalogue validation**

- Valid JSON.
- Expected operator/resource structure.
- Required fields.
- Valid resource URLs.
- Valid timestamps.
- Duplicate resource detection.

**Download validation**

- HTTP success.
- Correct content.
- Non-empty files.
- Correct file signatures.
- ZIP integrity.
- XML parseability.
- Protocol Buffers decoding.

**GTFS validation**

- Required files.
- Correct headers.
- Valid field types.
- Referential integrity.
- Valid stop coordinates.
- Valid route and trip relationships.
- Valid service calendars.
- Valid stop-time relationships.

**Spatial validation**

- Valid coordinates.
- Geographic range checks.
- Coordinate reference system checks.
- Province classification.
- Geometry validity.

**Real-time validation**

- Valid feed header.
- Freshness checks.
- Valid timestamps.
- Correct message types.
- Static entity matching.
- Duplicate observation detection.

Create a validation report for each ingestion job.

Do not silently discard invalid records.

Keep rejection reasons and relevant source information.

---

### 13. API AND FRONTEND INTEGRATION

Expose a clean and efficient data access layer for the application.

The frontend should be able to retrieve:

- Provinces.
- Municipalities.
- Operators.
- Transport modes.
- Stops.
- Routes.
- Trips.
- Timetables.
- Service calendars.
- Real-time vehicle positions.
- Real-time delays.
- Service alerts.
- Route geometries.

Support filtering by:

- Province.
- Municipality.
- Operator.
- Transport mode.
- Route.
- Stop.
- Geographic area.

Use PostGIS for geographic queries.

Create appropriate indexes for:

- Province identifiers.
- Operator identifiers.
- External identifiers.
- Route identifiers.
- Stop identifiers.
- Geometry columns.
- Observation timestamps.

Use Supabase Row Level Security for all exposed tables.

Keep ingestion operations on trusted server-side infrastructure.

Never expose Supabase service-role keys in the frontend.

---

### 14. TECHNOLOGY AND IMPLEMENTATION REQUIREMENTS

Use a robust, maintainable architecture.

Recommended technologies:

- Supabase PostgreSQL.
- PostGIS.
- Supabase Storage.
- Python for ingestion and ETL.
- FastAPI if an internal API or ingestion service is needed.
- Official GTFS and GTFS-Realtime specifications.
- Reliable XML processing libraries for SIRI and NeTEx.
- A maintained Protocol Buffers implementation.
- Docker for reproducible deployment.
- A scheduler such as cron, APScheduler or an appropriate job orchestration solution.

Use Supabase Edge Functions only for lightweight operations.

Do not attempt to process very large ZIP archives, complex NeTEx datasets or high-volume real-time ingestion entirely inside Edge Functions.

Use an external worker or containerised Python service for heavy processing.

Use Supabase migrations to manage schema changes.

Store all secrets in environment variables or an appropriate secrets manager.

Provide `.env.example` without real credentials.

---

### 15. AUTOMATION, LOGGING AND MONITORING

Build an administrative monitoring system.

For each operator, display:

- Name.
- Available formats.
- Number of discovered resources.
- Last catalogue update.
- Last successful download.
- Last successful static import.
- Last real-time update.
- Current ingestion status.
- Validation status.
- Error count.

For the whole platform, display:

- Number of discovered operators.
- Number of active resources.
- Number of GTFS feeds.
- Number of GTFS-RT feeds.
- Number of SIRI resources.
- Number of NETEX resources.
- Number of stops.
- Number of routes.
- Number of trips.
- Number of real-time observations.
- Number of failed jobs.
- Last successful catalogue scan.

Implement structured logs and error categorisation.

Send alerts for:

- Catalogue retrieval failures.
- Repeated download failures.
- Invalid resources.
- Failed imports.
- Stale real-time feeds.
- Unexpectedly large record-count changes.
- Missing operators or resources.

Provide retry mechanisms for failed jobs.

Do not require an administrator to manually restart the entire ingestion process.

---

### 16. SECURITY AND RELIABILITY

Implement:

- Supabase Row Level Security.
- Server-side service-role access only.
- Secure secrets management.
- Download size limits.
- Request timeouts.
- Retry limits.
- ZIP extraction safeguards against path traversal.
- XML protections against XXE and unsafe external entity resolution.
- Safe file handling.
- Database transaction management.
- Rate limiting.
- Input validation.
- Audit logs.

Treat all external resources as untrusted input.

Do not execute downloaded files.

Do not trust file extensions as proof of file type.

Validate actual content before processing.

---

### 17. TESTING REQUIREMENTS

Create automated tests for the entire pipeline.

Include:

1. JSON index discovery.
2. Parsing multiple operators.
3. Parsing multiple resources per operator.
4. Handling missing optional fields.
5. Handling spaces and special characters in URLs.
6. Detecting new operators.
7. Detecting new resources.
8. Detecting changed resources.
9. Downloading GTFS ZIP files.
10. Decoding GTFS-RT Protocol Buffers.
11. Parsing SIRI XML.
12. Parsing NeTEx archives.
13. Handling SHP resources.
14. Preventing cross-operator ID collisions.
15. Assigning stops to the correct province.
16. Handling cross-provincial routes.
17. Handling failed downloads.
18. Handling invalid ZIP files.
19. Handling malformed XML.
20. Handling stale real-time feeds.
21. Preventing duplicate imports.
22. Preserving previous production data after failed imports.
23. Running the pipeline repeatedly without creating duplicate records.

Use representative resources from different operators and formats.

Include unit tests, integration tests and end-to-end tests.

---

### 18. IMPLEMENTATION PHASES

Implement the project in controlled phases.

**Phase 1 — Catalogue discovery**

- Identify the real complete JSON index URL.
- Build the automatic index downloader.
- Parse every operator and resource.
- Save catalogue snapshots.
- Create the operator and resource registry.

**Phase 2 — GTFS Static ingestion**

- Download all GTFS resources.
- Validate ZIP files.
- Parse GTFS.
- Build the central relational model.
- Import stops, routes, trips, calendars and timetables.
- Implement source namespaces.

**Phase 3 — Provincial classification**

- Import official provincial boundaries.
- Enable PostGIS.
- Geographically classify stops.
- Build route-province relationships.
- Handle shared and cross-provincial services.

**Phase 4 — GTFS-Realtime**

- Discover all GTFS-RT resources.
- Identify Vehicle Positions, Trip Updates and Service Alerts.
- Decode Protocol Buffers.
- Associate real-time records with static feeds.
- Implement frequent updates and retention.

**Phase 5 — SIRI**

- Discover and parse SIRI resources.
- Implement the supported message types.
- Normalise compatible data.

**Phase 6 — NeTEx**

- Download and inspect NeTEx resources.
- Implement XML and archive processing.
- Normalise compatible entities.

**Phase 7 — SHP**

- Discover available SHP resources.
- Import spatial datasets.
- Connect relevant geometries with transport entities.

**Phase 8 — Production automation**

- Configure schedules.
- Implement monitoring.
- Add alerts.
- Add retry mechanisms.
- Optimise database queries.
- Complete security and performance testing.

Do not mark a phase as complete until its acceptance criteria are met.

---

### 19. REQUIRED PROJECT DELIVERABLES

Provide:

1. Complete architecture documentation.
2. Supabase SQL migrations.
3. PostGIS configuration.
4. Python ingestion project.
5. JSON catalogue discovery module.
6. Automatic resource download manager.
7. GTFS Static processor.
8. GTFS-Realtime processor.
9. SIRI processor.
10. NeTEx processor.
11. SHP processor or documented implementation plan if source availability prevents immediate completion.
12. Provincial classification module.
13. Supabase Storage integration.
14. Automated scheduling configuration.
15. Monitoring and logging.
16. Validation and error reports.
17. Automated tests.
18. Docker configuration.
19. `.env.example`.
20. Deployment instructions.
21. Documentation explaining how to add new formats and processors.
22. Documentation explaining how to recover from failed ingestion jobs.

Provide working code, not just architectural suggestions.

Do not leave core functionality as pseudocode, TODO comments or manual procedures.

If a particular format cannot be implemented because the source documentation or resource is unavailable, clearly document the limitation and implement the rest of the system.

---

### 20. ACCEPTANCE CRITERIA

The implementation is considered successful only when all of the following are true:

- The system automatically retrieves the complete official JSON index.
- It discovers every operator present in that index.
- It discovers every resource published for each operator.
- It reads the exact direct download URL from each resource entry.
- It supports resources with spaces and special characters in their URLs.
- It detects the format of each resource correctly.
- It downloads GTFS Static automatically.
- It decodes GTFS-Realtime resources correctly.
- It processes SIRI resources using the appropriate XML parser.
- It processes NeTEx resources using the appropriate parser.
- It can process SHP resources when available.
- It stores original files in Supabase Storage.
- It imports normalised data into Supabase PostgreSQL.
- It prevents identifier collisions between operators.
- It classifies stops geographically into Bizkaia, Gipuzkoa and Araba.
- It supports routes and operators that serve multiple provinces.
- It updates changed resources automatically.
- It does not unnecessarily download unchanged static resources.
- It preserves valid production data when an import fails.
- It records ingestion history, checksums and errors.
- It supports real-time transport information.
- It can discover new operators and resources without code changes.
- It runs automatically without manual ZIP downloads or manual operator selection.

---

### 21. IMPORTANT DEVELOPMENT INSTRUCTIONS

Before writing the final implementation:

1. Inspect the existing application, repository, database and Supabase configuration.
2. Reuse existing working components where appropriate.
3. Identify the actual official JSON index endpoint from the Moveuskadi catalogue.
4. Inspect real index entries and representative resources from different operators.
5. Verify the actual file structures and formats.
6. Confirm which resources are static and which are real-time.
7. Design the database around the actual data rather than assumptions.
8. Implement the ingestion pipeline incrementally.
9. Run tests against real representative resources.
10. Document any source limitations.

**Do not fabricate endpoints, operator names, resource URLs, transport data or successful import results.**

**Do not use a manually maintained list of operators.**

**Do not hardcode download URLs when the JSON index already provides them.**

**Do not assume that every resource is a ZIP file.**

**Do not treat GTFS-RT, SIRI and NeTEx as GTFS Static.**

**Do not classify an entire operator into one province without geographical evidence.**

**Do not overwrite valid production data with incomplete or failed imports.**
# MASTER TECHNICAL SPECIFICATION — AUTOMATED EUSKADI PUBLIC TRANSPORT DATA PLATFORM
## Complete Moveuskadi Data Ingestion, Normalisation, Real-Time Processing and Supabase Integration

### 1. PROJECT OBJECTIVE

Build a complete, production-ready, fully automated public transport data ingestion and management system for the Basque Country (Euskadi), Spain.

The system must discover, download, process, validate, normalise, store and continuously update public transport data from all available operators and transport services across the three provinces:

- Bizkaia
- Gipuzkoa
- Araba / Álava

The platform will use Supabase (PostgreSQL + PostGIS + Storage) as its central database and storage infrastructure.

The system must integrate all available transport operators and transport modes published through the official Moveuskadi data catalogue.

**The most important requirement: the entire process must be automatic.**

Do not require manual ZIP downloads, manual operator selection, manually maintained download URLs or manual database imports.

The implementation must use the complete JSON index published by Open Data Euskadi / Moveuskadi as the primary source for discovering available data resources.

Do not build a solution around a single operator or a fixed GTFS download URL.

---

### 2. OFFICIAL DATA SOURCE — MOVEUSKADI

Primary catalogue:

https://www.moveuskadi.euskadi.eus/aa27aMovilidadWar/descargaMov

Official Open Data Euskadi dataset:

https://opendata.euskadi.eus/catalogo/-/moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-operadores-horarios-paradas-calendario-tarifas-etc/

The catalogue provides a complete JSON index containing operators, available formats, direct resource URLs, file names and last-update timestamps.

The JSON index must be treated as the authoritative resource catalogue.

### 2.1. JSON index structure

The index groups resources by operator.

An illustrative example:

```json
{
  "Errenteria": [
    {
      "format": "GTFS-RT",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "name": "gtfsrt_errenteriako urbanoa_vehicle_positions.pb",
      "last-update": "2026-11-03 09:27:17"
    },
    {
      "format": "SIRI",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/errenteria/siri_errenteriako urbanoa_situation_exchange.xml",
      "name": "siri_errenteriako urbanoa_situation_exchange.xml",
      "last-update": "2026-11-03 09:27:15"
    }
  ],
  "Metro Bilbao": [
    {
      "format": "GTFS",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/gtfs_metro_bilbao.zip",
      "name": "gtfs_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:16"
    },
    {
      "format": "NETEX",
      "url": "https://opendata.euskadi.eus/transport/moveuskadi/metro_bilbao/netex_metro_bilbao.zip",
      "name": "netex_metro_bilbao.zip",
      "last-update": "2026-11-03 07:01:17"
    }
  ]
}
```

This is an example of the structure and not a complete list of resources.

The implementation must support the actual complete JSON document, including all operators and all resources it contains.

### 2.2. JSON index discovery

Implement a dedicated catalogue discovery service.

Requirements:

1. Automatically locate and retrieve the official complete JSON index.
2. Inspect the official catalogue page and its publicly accessible resources to identify the actual JSON index URL.
3. If the index URL is embedded in HTML or JavaScript, discover it programmatically.
4. Do not invent the JSON URL or assume an undocumented endpoint.
5. Store the discovered index URL in configuration.
6. Download the JSON index automatically on a configurable schedule.
7. Parse every operator and every resource.
8. Extract:
   - Operator name.
   - Format.
   - Direct download URL.
   - File name.
   - Last-update timestamp.
9. Preserve the original operator name and original metadata.
10. Support new operators appearing in future index updates without requiring code changes.
11. Detect operators that disappear from the index without immediately deleting their historical data.
12. Record every index retrieval, its timestamp, checksum and processing result.

The index must be dynamically parsed. Never hardcode individual operators or individual resource URLs.

### 2.3. URL handling

Use the exact URL provided by the JSON index.

Some file names and URLs may contain spaces or special characters. Handle URL encoding correctly without corrupting the original resource URL.

Do not construct URLs using operator names or file names when a direct URL is already provided.

Download resources using robust HTTP handling:

- Timeouts.
- Retry with exponential backoff.
- HTTP status validation.
- Content-length checks when available.
- Checksum calculation.
- Temporary files.
- Atomic promotion after successful validation.
- Logging of failed downloads.
- Support for large files.
- Appropriate User-Agent.
- Respect server rate limits and availability.

Never treat an HTTP error page as a valid ZIP, XML or Protocol Buffers resource.

---

### 3. SUPPORTED DATA FORMATS

The system must discover and process every format exposed by the index.

Implement separate ingestion modules for:

#### 3.1. GTFS Static

Expected resources commonly include ZIP archives containing:

- agency.txt
- stops.txt
- routes.txt
- trips.txt
- stop_times.txt
- calendar.txt
- calendar_dates.txt
- shapes.txt
- frequencies.txt
- transfers.txt
- pathways.txt
- levels.txt
- feed_info.txt
- attributions.txt

Not every feed will contain every file.

Requirements:

- Download automatically.
- Validate ZIP integrity.
- Inspect available files.
- Parse according to the GTFS specification.
- Validate references between agencies, stops, routes, trips and stop times.
- Preserve optional fields.
- Support feeds with different schemas and data quality.
- Normalise data into the common database model.
- Preserve original source records for traceability.

GTFS Static is the primary foundation for the transport network.

#### 3.2. GTFS-Realtime (GTFS-RT)

GTFS-RT resources may be individual Protocol Buffers files rather than ZIP archives.

Examples include:

- Vehicle Positions.
- Trip Updates.
- Service Alerts.

The JSON index may contain several GTFS-RT resources for the same operator.

The system must:

- Identify each GTFS-RT resource by its actual format and file name.
- Determine its message type where possible.
- Download and decode Protocol Buffers using the official GTFS-Realtime specification.
- Support vehicle position feeds.
- Support trip update feeds.
- Support service alert feeds.
- Validate feed headers and timestamps.
- Associate real-time records with their corresponding static GTFS entities whenever possible.
- Store observation timestamps and ingestion timestamps.
- Handle expired, missing or stale real-time information.
- Avoid duplicating observations unnecessarily.
- Maintain historical observations according to configurable retention policies.

Do not assume that every GTFS-RT URL returns a ZIP file.

Use the GTFS-Realtime Protocol Buffers definitions and a maintained compatible decoder.

If an operator publishes several real-time files, process each resource independently.

#### 3.3. SIRI

Support SIRI XML resources, including relevant SIRI service types such as:

- Situation Exchange.
- Estimated Timetable.
- Vehicle Monitoring.
- Stop Monitoring.
- Other supported SIRI services present in the published resources.

Requirements:

- Detect the actual SIRI message type.
- Parse XML safely.
- Support namespaces.
- Validate XML structure.
- Preserve timestamps and source identifiers.
- Normalise compatible data into the common transport model.
- Keep original XML files for traceability.
- Do not assume every SIRI resource has the same structure.

For example, a Situation Exchange XML resource must not be processed as if it were a GTFS static feed.

#### 3.4. NETEX

Support NeTEx resources, including ZIP archives and their XML contents.

Requirements:

- Detect archive type.
- Validate archive integrity.
- Extract XML safely.
- Support relevant NeTEx structures.
- Parse operators, networks, lines, routes, scheduled stops, timetables, service calendars and other supported entities.
- Preserve source identifiers and relationships.
- Map compatible entities to the common transport model.
- Maintain original source data.
- Handle large datasets and complex XML documents.

Do not assume that all NeTEx resources use the same packaging or XML structure.

#### 3.5. SHP

If SHP resources are available through the official catalogue or its FTP services, implement a separate spatial ingestion module.

Support:

- Shapefile.
- SHX.
- DBF.
- PRJ.
- Associated files.

Requirements:

- Validate that required components exist.
- Detect the original coordinate reference system.
- Convert geometries to the database's standard spatial reference system.
- Import compatible geometries into PostGIS.
- Associate spatial data with operators or routes when reliable identifiers exist.

Do not block the initial GTFS implementation while waiting for SHP integration.

---

### 4. OPERATOR DISCOVERY AND MANAGEMENT

Every operator in the JSON index must be discovered automatically.

Create a dynamic operator registry.

For each operator, store:

- Internal UUID.
- Original operator name.
- Normalised operator name.
- Slug.
- Active status.
- Available formats.
- Available resources.
- Last successful catalogue discovery.
- Last successful static import.
- Last successful real-time update.
- Source metadata.
- Assigned province or provinces, when known.
- Transport modes, when known.

Important:

An operator must not be assigned to a province solely because its name suggests a location.

Use reliable geographic evidence, such as stop coordinates, route geometry, official operator information or authoritative territorial boundaries.

Some operators may operate across more than one province. Support multiple province associations.

The same operator may publish GTFS, GTFS-RT, SIRI and NETEX resources simultaneously.

Treat each resource as a separate ingestion resource, while maintaining its relationship to the operator.

New operators and new formats must be discoverable without modifying the database schema or writing operator-specific ingestion code.

---

### 5. PROVINCIAL CLASSIFICATION — EUSKADI

The application must support three provinces:

1. Bizkaia.
2. Gipuzkoa.
3. Araba / Álava.

Create a province registry with stable internal identifiers.

Every stop must be geographically classified.

Use official administrative boundary geometries stored in PostGIS.

Recommended process:

1. Obtain authoritative provincial boundary polygons.
2. Store the polygons in PostGIS.
3. Validate and transform coordinate reference systems.
4. Read stop longitude and latitude.
5. Create geographic point geometries.
6. Determine which provincial polygon contains each stop.
7. Assign the corresponding province.
8. Record the classification method and confidence.
9. Flag stops that cannot be classified reliably.

Use spatial operations such as ST_Contains or ST_Intersects as appropriate.

Do not classify provinces using simple text matching or operator names.

### 5.1. Cross-provincial transport

Routes may cross provincial boundaries.

Therefore:

- A route may serve multiple provinces.
- A trip may cross provincial boundaries.
- An operator may serve multiple provinces.
- A stop belongs to the province determined by its geographical position.
- Route-province relationships must be derived from the geographical distribution of their stops or route geometry.

Create appropriate many-to-many relationships.

The application must support queries such as:

- All stops in Bizkaia.
- All routes serving Gipuzkoa.
- All operators serving Araba.
- Routes connecting Bizkaia and Gipuzkoa.
- All transport services within a province.
- Stops and routes near a given coordinate.

Do not duplicate a route merely because it crosses provincial boundaries.

---

### 6. CENTRAL SUPABASE DATABASE

Use one central Supabase project and one consistent data model for the whole Basque Country.

Enable PostGIS.

Use UUID primary keys for internal records.

Keep external identifiers as source identifiers, not as globally unique database primary keys.

### 6.1. Recommended core tables

Create a properly normalised relational schema, including:

**Geography and classification**

- provinces
- municipalities
- administrative_boundaries
- stop_provinces
- route_provinces

**Operators and sources**

- transport_operators
- transport_modes
- operator_transport_modes
- operator_provinces
- gtfs_sources
- source_resources
- source_resource_formats

**Catalogue and ingestion**

- catalogue_snapshots
- catalogue_resources
- ingestion_jobs
- ingestion_job_logs
- ingestion_errors
- feed_versions
- feed_files
- resource_checksums

**GTFS Static**

- agencies
- stops
- routes
- trips
- stop_times
- calendars
- calendar_dates
- shapes
- frequencies
- transfers
- pathways
- levels
- feed_info
- attributions

**Real-time**

- realtime_feed_snapshots
- vehicle_positions
- trip_updates
- stop_time_updates
- service_alerts
- alert_informed_entities
- realtime_observations

**Other formats**

- siri_messages
- siri_vehicle_observations
- siri_situation_exchanges
- netex_resources
- netex_lines
- netex_stops
- netex_routes
- netex_services
- spatial_resources

Adapt the final schema to the actual contents of the available feeds.

Do not create unnecessary duplicate tables if a well-designed shared model is more appropriate.

### 6.2. Identifier collision prevention

GTFS identifiers are not guaranteed to be globally unique.

Never assume that two operators use different stop IDs, route IDs or trip IDs.

Implement a source namespace.

For example:

- source_id
- source_operator_id
- external_stop_id
- external_route_id
- external_trip_id

Use unique constraints based on the source namespace and external identifier.

This must prevent collisions between operators.

Maintain mappings between original identifiers and internal UUIDs.

Do not overwrite one operator's data with another operator's data.

### 6.3. Historical versions

Maintain feed versions.

Each successful import must record:

- Operator.
- Resource.
- Format.
- Source URL.
- Catalogue timestamp.
- Download timestamp.
- Checksum.
- File size.
- Import start and end times.
- Number of processed records.
- Number of rejected records.
- Validation status.
- Software/parser version.

Preserve historical feed versions when useful for auditing and comparison.

---

### 7. AUTOMATED INGESTION ARCHITECTURE

Build a modular ingestion pipeline.

Recommended architecture:

**A. Catalogue discovery service**

- Retrieves the official JSON index.
- Detects all operators and resources.
- Compares the new index with the previous snapshot.
- Detects new resources, removed resources and updated resources.
- Creates ingestion jobs.

**B. Download service**

- Downloads resources using the exact URLs in the index.
- Supports concurrent downloads with configurable limits.
- Implements retries and backoff.
- Verifies files.
- Calculates checksums.
- Stores raw files in Supabase Storage.

**C. Format detection and routing**

Routes each resource to the correct processor based on the actual catalogue format and validated file characteristics.

Do not process every resource as GTFS.

**D. Processing services**

Independent processors for:

- GTFS Static.
- GTFS-Realtime.
- SIRI.
- NETEX.
- SHP.

**E. Normalisation service**

Maps compatible data to the common Supabase schema.

**F. Spatial classification service**

Assigns stops, routes and operators to the appropriate provinces where supported by reliable evidence.

**G. Validation service**

Runs structural, relational and geographical checks.

**H. Publication service**

Publishes successfully validated data into production tables.

Use staging tables and atomic transactions where possible.

**I. Monitoring service**

Records processing status, errors, metrics and last successful updates.

### 7.1. Safe publication

Never destroy valid production data because a new download or import fails.

Use the following approach:

1. Download to temporary storage.
2. Validate the resource.
3. Import into staging tables or a new feed version.
4. Check record counts and relationships.
5. Run validation.
6. Publish the new version transactionally or through a controlled version switch.
7. Retain the previous working version until the new version is confirmed.

Failed imports must not leave partially updated production data.

---

### 8. AUTOMATIC UPDATE SCHEDULE

Implement configurable update schedules.

Suggested initial defaults:

| Process | Suggested frequency |
|---|---|
| JSON catalogue discovery | Every 15 minutes |
| GTFS Static change detection | Every 6 hours |
| Changed GTFS Static downloads | When catalogue metadata or checksum indicates a change |
| GTFS-RT Vehicle Positions | Every 15–30 seconds, subject to source limits |
| GTFS-RT Trip Updates | Every 30–60 seconds, subject to source limits |
| GTFS-RT Service Alerts | Every 1–5 minutes, subject to source limits |
| SIRI | According to source update frequency |
| NETEX | When the source resource changes |
| SHP | When the source resource changes |

These are configurable starting values, not guaranteed publication frequencies.

Use the index's `last-update` timestamp to detect potential changes.

However, do not rely exclusively on that timestamp.

Use checksums, HTTP metadata and source validation where appropriate.

Do not repeatedly download unchanged large resources unnecessarily.

For real-time feeds, do not assume that a file timestamp accurately represents the freshness of the actual observations.

Store both source timestamps and ingestion timestamps.

---

### 9. SUPABASE STORAGE

Create a structured Storage organisation.

Example:

```text
moveuskadi/
  catalogue/
    snapshots/
  raw/
    bizkaia/
    gipuzkoa/
    araba/
    unclassified/
  processed/
    gtfs/
    gtfsrt/
    siri/
    netex/
    shp/
  failed/
    downloads/
    processing/
  archives/
    historical/
```

The exact folder organisation may be improved during implementation.

Requirements:

- Store raw original resources.
- Store the original JSON index snapshots.
- Preserve downloaded files for auditability.
- Use versioned file paths.
- Avoid overwriting the only copy of a previous resource.
- Apply retention policies.
- Restrict access to internal ingestion files.
- Do not expose service-role credentials to frontend code.

If a resource cannot be confidently assigned to one province, keep it in an unclassified or shared area until classification is established.

---

### 10. GTFS STATIC AND REAL-TIME ASSOCIATION

A critical requirement is connecting real-time information to the correct static transport network.

Implement matching using:

- Operator/source namespace.
- Feed identifiers.
- Route IDs.
- Trip IDs.
- Stop IDs.
- Vehicle IDs.
- Service dates.
- Start times.
- Source-provided references.

Do not assume an ID in one operator's GTFS-RT feed belongs to another operator.

When an association cannot be established:

- Preserve the original real-time record.
- Mark the association as unresolved.
- Do not invent a route, stop or trip.
- Allow subsequent matching when static data becomes available.

Vehicle positions should support:

- Latitude.
- Longitude.
- Bearing.
- Speed.
- Vehicle identifier.
- Trip reference.
- Route reference.
- Timestamp.
- Source operator.
- Source resource.

Trip updates should support:

- Trip reference.
- Route reference.
- Stop sequence.
- Stop reference.
- Arrival and departure predictions.
- Delays.
- Relationship to the scheduled service.

Service alerts should support:

- Header and description translations.
- Active periods.
- Cause and effect.
- Informed entities.
- Affected routes, trips and stops.

Implement historical retention and deduplication strategies to avoid uncontrolled database growth.

---

### 11. TRANSPORT MODES

The platform must support all relevant transport modes published through Moveuskadi, including where available:

- Urban buses.
- Interurban buses.
- Regional buses.
- Metro.
- Tram.
- Commuter rail.
- Regional rail.
- Funiculars.
- Cable or other special transport services.
- Ferries and other water transport.
- Other public transport services represented in the catalogue.

Do not hardcode the list of operators or assume that every transport mode is present in every province.

Create a flexible transport-mode registry.

An operator may provide multiple modes.

A route must have an associated mode where the source provides enough information to determine it reliably.

---

### 12. VALIDATION AND DATA QUALITY

Implement comprehensive validation.

**Catalogue validation**

- Valid JSON.
- Expected operator/resource structure.
- Required fields.
- Valid resource URLs.
- Valid timestamps.
- Duplicate resource detection.

**Download validation**

- HTTP success.
- Correct content.
- Non-empty files.
- Correct file signatures.
- ZIP integrity.
- XML parseability.
- Protocol Buffers decoding.

**GTFS validation**

- Required files.
- Correct headers.
- Valid field types.
- Referential integrity.
- Valid stop coordinates.
- Valid route and trip relationships.
- Valid service calendars.
- Valid stop-time relationships.

**Spatial validation**

- Valid coordinates.
- Geographic range checks.
- Coordinate reference system checks.
- Province classification.
- Geometry validity.

**Real-time validation**

- Valid feed header.
- Freshness checks.
- Valid timestamps.
- Correct message types.
- Static entity matching.
- Duplicate observation detection.

Create a validation report for each ingestion job.

Do not silently discard invalid records.

Keep rejection reasons and relevant source information.

---

### 13. API AND FRONTEND INTEGRATION

Expose a clean and efficient data access layer for the application.

The frontend should be able to retrieve:

- Provinces.
- Municipalities.
- Operators.
- Transport modes.
- Stops.
- Routes.
- Trips.
- Timetables.
- Service calendars.
- Real-time vehicle positions.
- Real-time delays.
- Service alerts.
- Route geometries.

Support filtering by:

- Province.
- Municipality.
- Operator.
- Transport mode.
- Route.
- Stop.
- Geographic area.

Use PostGIS for geographic queries.

Create appropriate indexes for:

- Province identifiers.
- Operator identifiers.
- External identifiers.
- Route identifiers.
- Stop identifiers.
- Geometry columns.
- Observation timestamps.

Use Supabase Row Level Security for all exposed tables.

Keep ingestion operations on trusted server-side infrastructure.

Never expose Supabase service-role keys in the frontend.

---

### 14. TECHNOLOGY AND IMPLEMENTATION REQUIREMENTS

Use a robust, maintainable architecture.

Recommended technologies:

- Supabase PostgreSQL.
- PostGIS.
- Supabase Storage.
- Python for ingestion and ETL.
- FastAPI if an internal API or ingestion service is needed.
- Official GTFS and GTFS-Realtime specifications.
- Reliable XML processing libraries for SIRI and NeTEx.
- A maintained Protocol Buffers implementation.
- Docker for reproducible deployment.
- A scheduler such as cron, APScheduler or an appropriate job orchestration solution.

Use Supabase Edge Functions only for lightweight operations.

Do not attempt to process very large ZIP archives, complex NeTEx datasets or high-volume real-time ingestion entirely inside Edge Functions.

Use an external worker or containerised Python service for heavy processing.

Use Supabase migrations to manage schema changes.

Store all secrets in environment variables or an appropriate secrets manager.

Provide `.env.example` without real credentials.

---

### 15. AUTOMATION, LOGGING AND MONITORING

Build an administrative monitoring system.

For each operator, display:

- Name.
- Available formats.
- Number of discovered resources.
- Last catalogue update.
- Last successful download.
- Last successful static import.
- Last real-time update.
- Current ingestion status.
- Validation status.
- Error count.

For the whole platform, display:

- Number of discovered operators.
- Number of active resources.
- Number of GTFS feeds.
- Number of GTFS-RT feeds.
- Number of SIRI resources.
- Number of NETEX resources.
- Number of stops.
- Number of routes.
- Number of trips.
- Number of real-time observations.
- Number of failed jobs.
- Last successful catalogue scan.

Implement structured logs and error categorisation.

Send alerts for:

- Catalogue retrieval failures.
- Repeated download failures.
- Invalid resources.
- Failed imports.
- Stale real-time feeds.
- Unexpectedly large record-count changes.
- Missing operators or resources.

Provide retry mechanisms for failed jobs.

Do not require an administrator to manually restart the entire ingestion process.

---

### 16. SECURITY AND RELIABILITY

Implement:

- Supabase Row Level Security.
- Server-side service-role access only.
- Secure secrets management.
- Download size limits.
- Request timeouts.
- Retry limits.
- ZIP extraction safeguards against path traversal.
- XML protections against XXE and unsafe external entity resolution.
- Safe file handling.
- Database transaction management.
- Rate limiting.
- Input validation.
- Audit logs.

Treat all external resources as untrusted input.

Do not execute downloaded files.

Do not trust file extensions as proof of file type.

Validate actual content before processing.

---

### 17. TESTING REQUIREMENTS

Create automated tests for the entire pipeline.

Include:

1. JSON index discovery.
2. Parsing multiple operators.
3. Parsing multiple resources per operator.
4. Handling missing optional fields.
5. Handling spaces and special characters in URLs.
6. Detecting new operators.
7. Detecting new resources.
8. Detecting changed resources.
9. Downloading GTFS ZIP files.
10. Decoding GTFS-RT Protocol Buffers.
11. Parsing SIRI XML.
12. Parsing NeTEx archives.
13. Handling SHP resources.
14. Preventing cross-operator ID collisions.
15. Assigning stops to the correct province.
16. Handling cross-provincial routes.
17. Handling failed downloads.
18. Handling invalid ZIP files.
19. Handling malformed XML.
20. Handling stale real-time feeds.
21. Preventing duplicate imports.
22. Preserving previous production data after failed imports.
23. Running the pipeline repeatedly without creating duplicate records.

Use representative resources from different operators and formats.

Include unit tests, integration tests and end-to-end tests.

---

### 18. IMPLEMENTATION PHASES

Implement the project in controlled phases.

**Phase 1 — Catalogue discovery**

- Identify the real complete JSON index URL.
- Build the automatic index downloader.
- Parse every operator and resource.
- Save catalogue snapshots.
- Create the operator and resource registry.

**Phase 2 — GTFS Static ingestion**

- Download all GTFS resources.
- Validate ZIP files.
- Parse GTFS.
- Build the central relational model.
- Import stops, routes, trips, calendars and timetables.
- Implement source namespaces.

**Phase 3 — Provincial classification**

- Import official provincial boundaries.
- Enable PostGIS.
- Geographically classify stops.
- Build route-province relationships.
- Handle shared and cross-provincial services.

**Phase 4 — GTFS-Realtime**

- Discover all GTFS-RT resources.
- Identify Vehicle Positions, Trip Updates and Service Alerts.
- Decode Protocol Buffers.
- Associate real-time records with static feeds.
- Implement frequent updates and retention.

**Phase 5 — SIRI**

- Discover and parse SIRI resources.
- Implement the supported message types.
- Normalise compatible data.

**Phase 6 — NeTEx**

- Download and inspect NeTEx resources.
- Implement XML and archive processing.
- Normalise compatible entities.

**Phase 7 — SHP**

- Discover available SHP resources.
- Import spatial datasets.
- Connect relevant geometries with transport entities.

**Phase 8 — Production automation**

- Configure schedules.
- Implement monitoring.
- Add alerts.
- Add retry mechanisms.
- Optimise database queries.
- Complete security and performance testing.

Do not mark a phase as complete until its acceptance criteria are met.

---

### 19. REQUIRED PROJECT DELIVERABLES

Provide:

1. Complete architecture documentation.
2. Supabase SQL migrations.
3. PostGIS configuration.
4. Python ingestion project.
5. JSON catalogue discovery module.
6. Automatic resource download manager.
7. GTFS Static processor.
8. GTFS-Realtime processor.
9. SIRI processor.
10. NeTEx processor.
11. SHP processor or documented implementation plan if source availability prevents immediate completion.
12. Provincial classification module.
13. Supabase Storage integration.
14. Automated scheduling configuration.
15. Monitoring and logging.
16. Validation and error reports.
17. Automated tests.
18. Docker configuration.
19. `.env.example`.
20. Deployment instructions.
21. Documentation explaining how to add new formats and processors.
22. Documentation explaining how to recover from failed ingestion jobs.

Provide working code, not just architectural suggestions.

Do not leave core functionality as pseudocode, TODO comments or manual procedures.

If a particular format cannot be implemented because the source documentation or resource is unavailable, clearly document the limitation and implement the rest of the system.

---

### 20. ACCEPTANCE CRITERIA

The implementation is considered successful only when all of the following are true:

- The system automatically retrieves the complete official JSON index.
- It discovers every operator present in that index.
- It discovers every resource published for each operator.
- It reads the exact direct download URL from each resource entry.
- It supports resources with spaces and special characters in their URLs.
- It detects the format of each resource correctly.
- It downloads GTFS Static automatically.
- It decodes GTFS-Realtime resources correctly.
- It processes SIRI resources using the appropriate XML parser.
- It processes NeTEx resources using the appropriate parser.
- It can process SHP resources when available.
- It stores original files in Supabase Storage.
- It imports normalised data into Supabase PostgreSQL.
- It prevents identifier collisions between operators.
- It classifies stops geographically into Bizkaia, Gipuzkoa and Araba.
- It supports routes and operators that serve multiple provinces.
- It updates changed resources automatically.
- It does not unnecessarily download unchanged static resources.
- It preserves valid production data when an import fails.
- It records ingestion history, checksums and errors.
- It supports real-time transport information.
- It can discover new operators and resources without code changes.
- It runs automatically without manual ZIP downloads or manual operator selection.

---

### 21. IMPORTANT DEVELOPMENT INSTRUCTIONS

Before writing the final implementation:

1. Inspect the existing application, repository, database and Supabase configuration.
2. Reuse existing working components where appropriate.
3. Identify the actual official JSON index endpoint from the Moveuskadi catalogue.
4. Inspect real index entries and representative resources from different operators.
5. Verify the actual file structures and formats.
6. Confirm which resources are static and which are real-time.
7. Design the database around the actual data rather than assumptions.
8. Implement the ingestion pipeline incrementally.
9. Run tests against real representative resources.
10. Document any source limitations.

**Do not fabricate endpoints, operator names, resource URLs, transport data or successful import results.**

**Do not use a manually maintained list of operators.**

**Do not hardcode download URLs when the JSON index already provides them.**

**Do not assume that every resource is a ZIP file.**

**Do not treat GTFS-RT, SIRI and NeTEx as GTFS Static.**

**Do not classify an entire operator into one province without geographical evidence.**

**Do not overwrite valid production data with incomplete or failed imports.**

The complete JSON index is the source of truth for resource discovery. The ingestion engine must be dynamic, format-aware, operator-independent, geographically accurate and fully automated.

The final result must be a scalable, reliable and production-ready public transport data platform covering the entire Basque Country.
The complete JSON index is the source of truth for resource discovery. The ingestion engine must be dynamic, format-aware, operator-independent, geographically accurate and fully automated.

The final result must be a scalable, reliable and production-ready public transport data platform covering the entire Basque Country.
The complete JSON index is the source of truth for resource discovery. The ingestion engine must be dynamic, format-aware, operator-independent, geographically accurate and fully automated.

The final result must be a scalable, reliable and production-ready public transport data platform covering the entire Basque Country.ll default '#025DA9',
  website_url text,
  source_metadata jsonb not null default '{}'::jsonb,
  last_catalogue_seen_at timestamptz not null default now(),
  last_static_import_at timestamptz,
  last_realtime_sync_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_operators_slug on public.transport_operators (slug);
create index if not exists idx_operators_active on public.transport_operators (is_active);

create table if not exists public.operator_provinces (
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  province_code text not null references public.provinces(code) on delete cascade,
  is_primary boolean not null default false,
  confidence double precision not null default 1.0,
  evidence_source text not null default 'spatial_stops_distribution',
  primary key (operator_id, province_code)
);

create table if not exists public.operator_transport_modes (
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  mode_id text not null references public.transport_modes(id) on delete cascade,
  primary key (operator_id, mode_id)
);

-- ==============================================================================
-- 4. CATALOGUE DISCOVERY & INGESTION TRACKING
-- ==============================================================================

create table if not exists public.catalogue_snapshots (
  id uuid primary key default gen_random_uuid(),
  catalogue_url text not null,
  retrieved_at timestamptz not null default now(),
  catalogue_last_update text,
  total_operators int not null default 0,
  total_resources int not null default 0,
  checksum text not null,
  raw_payload jsonb not null,
  status text not null default 'processed' check (status in ('pending', 'processed', 'failed')),
  error_message text
);

create index if not exists idx_catalogue_retrieved on public.catalogue_snapshots (retrieved_at desc);

create table if not exists public.catalogue_resources (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  format text not null, -- 'GTFS', 'GTFS-RT', 'SIRI', 'NETEX', 'SHP'
  name text not null,
  url text not null,
  catalogue_last_update text,
  last_discovered_at timestamptz not null default now(),
  last_downloaded_at timestamptz,
  last_checksum text,
  file_size_bytes bigint,
  is_active boolean not null default true,
  unique (operator_id, url)
);

create index if not exists idx_catalogue_resources_op on public.catalogue_resources (operator_id, format);

create table if not exists public.feed_versions (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  format text not null, -- 'GTFS', 'NETEX'
  resource_url text not null,
  catalogue_timestamp text,
  download_timestamp timestamptz not null default now(),
  checksum text not null,
  file_size_bytes bigint not null default 0,
  status text not null default 'importing' check (status in ('importing', 'active', 'deprecated', 'failed')),
  records_processed jsonb not null default '{}'::jsonb,
  validation_status text not null default 'pending' check (validation_status in ('pending', 'passed', 'warnings', 'failed')),
  validation_report jsonb not null default '{}'::jsonb,
  activated_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_feed_versions_op_status on public.feed_versions (operator_id, status);

create table if not exists public.ingestion_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null check (job_type in ('catalogue_discovery', 'gtfs_static', 'gtfs_realtime', 'siri', 'netex', 'shp', 'spatial_classification')),
  operator_id uuid references public.transport_operators(id) on delete cascade,
  feed_version_id uuid references public.feed_versions(id) on delete set null,
  resource_url text,
  status text not null default 'running' check (status in ('running', 'completed', 'failed', 'skipped')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  metrics jsonb not null default '{}'::jsonb,
  error_message text
);

create index if not exists idx_ingestion_jobs_started on public.ingestion_jobs (started_at desc);

create table if not exists public.ingestion_errors (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.ingestion_jobs(id) on delete cascade,
  operator_id uuid references public.transport_operators(id) on delete set null,
  error_type text not null,
  error_message text not null,
  context_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ==============================================================================
-- 5. NORMALIZED GTFS STATIC MODEL (SOURCE SCOPED TO PREVENT COLLISIONS)
-- ==============================================================================

create table if not exists public.gtfs_agencies (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  agency_id text not null,
  agency_name text not null,
  agency_url text not null,
  agency_timezone text not null default 'Europe/Madrid',
  agency_lang text,
  agency_phone text,
  unique (feed_version_id, agency_id)
);

create table if not exists public.gtfs_stops (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  external_stop_id text not null,
  stop_code text,
  stop_name text not null,
  stop_desc text,
  latitude double precision not null,
  longitude double precision not null,
  geom geometry(Point, 4326) not null,
  zone_id text,
  stop_url text,
  location_type int not null default 0,
  parent_station_id uuid references public.gtfs_stops(id) on delete set null,
  wheelchair_boarding int default 0,
  platform_code text,
  unique (feed_version_id, external_stop_id)
);

create index if not exists idx_gtfs_stops_geom on public.gtfs_stops using gist (geom);
create index if not exists idx_gtfs_stops_op_ext on public.gtfs_stops (operator_id, external_stop_id);
create index if not exists idx_gtfs_stops_feed on public.gtfs_stops (feed_version_id);

create table if not exists public.stop_provinces (
  stop_id uuid not null references public.gtfs_stops(id) on delete cascade,
  province_code text not null references public.provinces(code) on delete cascade,
  classification_method text not null default 'spatial_polygon_containment',
  confidence double precision not null default 1.0,
  created_at timestamptz not null default now(),
  primary key (stop_id, province_code)
);

create table if not exists public.gtfs_routes (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  agency_id text,
  external_route_id text not null,
  route_short_name text not null,
  route_long_name text not null,
  route_desc text,
  route_type int not null,
  route_url text,
  route_color text not null default '025DA9',
  route_text_color text not null default 'FFFFFF',
  unique (feed_version_id, external_route_id)
);

create index if not exists idx_gtfs_routes_feed on public.gtfs_routes (feed_version_id);
create index if not exists idx_gtfs_routes_op_ext on public.gtfs_routes (operator_id, external_route_id);

create table if not exists public.route_provinces (
  route_id uuid not null references public.gtfs_routes(id) on delete cascade,
  province_code text not null references public.provinces(code) on delete cascade,
  primary key (route_id, province_code)
);

create table if not exists public.gtfs_calendars (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  service_id text not null,
  monday smallint not null,
  tuesday smallint not null,
  wednesday smallint not null,
  thursday smallint not null,
  friday smallint not null,
  saturday smallint not null,
  sunday smallint not null,
  start_date text not null, -- 'YYYYMMDD'
  end_date text not null,   -- 'YYYYMMDD'
  unique (feed_version_id, service_id)
);

create table if not exists public.gtfs_calendar_dates (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  service_id text not null,
  date text not null, -- 'YYYYMMDD'
  exception_type smallint not null check (exception_type in (1, 2)), -- 1 = added, 2 = removed
  unique (feed_version_id, service_id, date)
);

create table if not exists public.gtfs_shapes (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  shape_id text not null,
  shape_pt_lat double precision not null,
  shape_pt_lon double precision not null,
  shape_pt_sequence int not null,
  shape_dist_traveled double precision,
  geom geometry(Point, 4326),
  unique (feed_version_id, shape_id, shape_pt_sequence)
);

create index if not exists idx_gtfs_shapes_lookup on public.gtfs_shapes (feed_version_id, shape_id, shape_pt_sequence);

create table if not exists public.gtfs_trips (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  route_id uuid not null references public.gtfs_routes(id) on delete cascade,
  external_trip_id text not null,
  service_id text not null,
  trip_headsign text,
  trip_short_name text,
  direction_id smallint check (direction_id in (0, 1)),
  block_id text,
  shape_id text,
  wheelchair_accessible smallint default 0,
  bikes_allowed smallint default 0,
  unique (feed_version_id, external_trip_id)
);

create index if not exists idx_gtfs_trips_feed_ext on public.gtfs_trips (feed_version_id, external_trip_id);
create index if not exists idx_gtfs_trips_route on public.gtfs_trips (route_id);

create table if not exists public.gtfs_stop_times (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  trip_id uuid not null references public.gtfs_trips(id) on delete cascade,
  stop_id uuid not null references public.gtfs_stops(id) on delete cascade,
  external_trip_id text not null,
  external_stop_id text not null,
  arrival_time text not null,   -- GTFS formatted, e.g. '07:15:00' or past midnight '24:12:00'
  departure_time text not null,
  stop_sequence int not null,
  stop_headsign text,
  pickup_type smallint default 0,
  drop_off_type smallint default 0,
  shape_dist_traveled double precision,
  timepoint smallint default 1,
  unique (feed_version_id, external_trip_id, stop_sequence)
);

create index if not exists idx_gtfs_stop_times_trip on public.gtfs_stop_times (trip_id, stop_sequence);
create index if not exists idx_gtfs_stop_times_stop on public.gtfs_stop_times (stop_id);

create table if not exists public.gtfs_frequencies (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  trip_id uuid not null references public.gtfs_trips(id) on delete cascade,
  start_time text not null,
  end_time text not null,
  headway_secs int not null,
  exact_times smallint default 0
);

create table if not exists public.gtfs_transfers (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  from_stop_id uuid not null references public.gtfs_stops(id) on delete cascade,
  to_stop_id uuid not null references public.gtfs_stops(id) on delete cascade,
  transfer_type smallint not null default 0,
  min_transfer_time int
);

create table if not exists public.gtfs_attributions (
  id uuid primary key default gen_random_uuid(),
  feed_version_id uuid not null references public.feed_versions(id) on delete cascade,
  organization_name text not null,
  is_producer boolean default false,
  is_operator boolean default true,
  is_authority boolean default false,
  attribution_url text
);

-- ==============================================================================
-- 6. REAL-TIME TELEMETRY (GTFS-RT) & OBSERVATIONS
-- ==============================================================================

create table if not exists public.realtime_feed_snapshots (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  feed_type text not null check (feed_type in ('vehicle_positions', 'trip_updates', 'service_alerts', 'siri')),
  resource_url text not null,
  feed_timestamp timestamptz not null,
  ingested_at timestamptz not null default now(),
  entity_count int not null default 0,
  checksum text not null
);

create index if not exists idx_rt_snapshots_op on public.realtime_feed_snapshots (operator_id, ingested_at desc);

create table if not exists public.vehicle_positions (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  snapshot_id uuid references public.realtime_feed_snapshots(id) on delete cascade,
  vehicle_id text not null,
  vehicle_label text,
  license_plate text,
  external_trip_id text,
  external_route_id text,
  trip_id uuid references public.gtfs_trips(id) on delete set null,
  route_id uuid references public.gtfs_routes(id) on delete set null,
  latitude double precision not null,
  longitude double precision not null,
  geom geometry(Point, 4326) not null,
  bearing double precision,
  odometer double precision,
  speed double precision,
  current_stop_sequence int,
  current_status text, -- 'INCOMING_AT', 'STOPPED_AT', 'IN_TRANSIT_TO'
  timestamp timestamptz not null,
  congestion_level text,
  occupancy_status text,
  is_latest boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_vehicle_positions_geom on public.vehicle_positions using gist (geom);
create index if not exists idx_vehicle_positions_latest on public.vehicle_positions (operator_id, is_latest) where is_latest = true;
create index if not exists idx_vehicle_positions_vehicle on public.vehicle_positions (operator_id, vehicle_id);

create table if not exists public.trip_updates (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  snapshot_id uuid references public.realtime_feed_snapshots(id) on delete cascade,
  external_trip_id text not null,
  external_route_id text,
  trip_id uuid references public.gtfs_trips(id) on delete set null,
  route_id uuid references public.gtfs_routes(id) on delete set null,
  vehicle_id text,
  start_time text,
  start_date text,
  schedule_relationship text, -- 'SCHEDULED', 'ADDED', 'UNSCHEDULED', 'CANCELED'
  timestamp timestamptz not null,
  delay_seconds int,
  created_at timestamptz not null default now()
);

create index if not exists idx_trip_updates_trip on public.trip_updates (operator_id, external_trip_id);

create table if not exists public.stop_time_updates (
  id uuid primary key default gen_random_uuid(),
  trip_update_id uuid not null references public.trip_updates(id) on delete cascade,
  stop_sequence int,
  external_stop_id text,
  stop_id uuid references public.gtfs_stops(id) on delete set null,
  arrival_delay int,
  arrival_time timestamptz,
  arrival_uncertainty int,
  departure_delay int,
  departure_time timestamptz,
  departure_uncertainty int,
  schedule_relationship text
);

create index if not exists idx_stop_time_updates_stop on public.stop_time_updates (external_stop_id);

create table if not exists public.service_alerts (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  external_alert_id text not null,
  cause text,
  effect text,
  header_text jsonb not null default '{}'::jsonb, -- translations: {"es": "...", "eu": "..."}
  description_text jsonb not null default '{}'::jsonb,
  url_text text,
  severity_level text,
  active_period_start timestamptz,
  active_period_end timestamptz,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (operator_id, external_alert_id)
);

create table if not exists public.alert_informed_entities (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.service_alerts(id) on delete cascade,
  external_agency_id text,
  external_route_id text,
  route_id uuid references public.gtfs_routes(id) on delete set null,
  external_trip_id text,
  trip_id uuid references public.gtfs_trips(id) on delete set null,
  external_stop_id text,
  stop_id uuid references public.gtfs_stops(id) on delete set null
);

-- ==============================================================================
-- 7. SIRI, NETEX & SPATIAL RESOURCES
-- ==============================================================================

create table if not exists public.siri_vehicle_observations (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  vehicle_ref text not null,
  line_ref text,
  direction_ref text,
  latitude double precision not null,
  longitude double precision not null,
  geom geometry(Point, 4326) not null,
  recorded_at timestamptz not null,
  delay_seconds int,
  created_at timestamptz not null default now()
);

create index if not exists idx_siri_obs_geom on public.siri_vehicle_observations using gist (geom);

create table if not exists public.siri_situation_exchanges (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  situation_number text not null,
  summary text not null,
  description text,
  severity text,
  validity_start timestamptz,
  validity_end timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.netex_resources (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid not null references public.transport_operators(id) on delete cascade,
  feed_version_id uuid references public.feed_versions(id) on delete cascade,
  resource_name text not null,
  elements_parsed jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.spatial_resources (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid references public.transport_operators(id) on delete set null,
  name text not null,
  original_crs text not null default 'EPSG:25830',
  feature_count int not null default 0,
  geom_type text not null,
  created_at timestamptz not null default now()
);

-- ==============================================================================
-- 8. STORED PROCEDURES & ATOMIC OPERATIONS
-- ==============================================================================

-- Stored Procedure: Classify Stops by Provincial Containment
create or replace function public.classify_stops_provinces(p_feed_version_id uuid)
returns table(classified_count bigint, unclassified_count bigint) as $$
declare
  v_classified bigint := 0;
  v_unclassified bigint := 0;
begin
  -- Insert containment into stop_provinces
  insert into public.stop_provinces (stop_id, province_code, classification_method, confidence)
  select
    s.id as stop_id,
    b.code as province_code,
    'spatial_polygon_containment' as classification_method,
    1.0 as confidence
  from public.gtfs_stops s
  join public.administrative_boundaries b
    on b.entity_type = 'province'
   and st_contains(b.geom, s.geom)
  where s.feed_version_id = p_feed_version_id
  on conflict (stop_id, province_code) do nothing;

  get diagnostics v_classified = row_count;

  -- Derive Route Provinces from Stop Provinces
  insert into public.route_provinces (route_id, province_code)
  select distinct
    r.id as route_id,
    sp.province_code
  from public.gtfs_routes r
  join public.gtfs_trips t on t.route_id = r.id
  join public.gtfs_stop_times st on st.trip_id = t.id
  join public.stop_provinces sp on sp.stop_id = st.stop_id
  where r.feed_version_id = p_feed_version_id
  on conflict (route_id, province_code) do nothing;

  -- Count unclassified stops
  select count(*) into v_unclassified
  from public.gtfs_stops s
  where s.feed_version_id = p_feed_version_id
    and not exists (
      select 1 from public.stop_provinces sp where sp.stop_id = s.id
    );

  return query select v_classified, v_unclassified;
end;
$$ language plpgsql security definer set search_path = public, extensions;

-- Stored Procedure: Atomic Feed Version Activation and Rollback
create or replace function public.activate_feed_version(p_feed_version_id uuid)
returns boolean as $$
declare
  v_operator_id uuid;
  v_old_version_id uuid;
begin
  select operator_id into v_operator_id
  from public.feed_versions
  where id = p_feed_version_id;

  if v_operator_id is null then
    raise exception 'Feed version % not found', p_feed_version_id;
  end if;

  -- Deprecate previous active versions for this operator
  update public.feed_versions
  set status = 'deprecated'
  where operator_id = v_operator_id
    and status = 'active'
    and id <> p_feed_version_id;

  -- Activate new version
  update public.feed_versions
  set status = 'active',
      activated_at = now()
  where id = p_feed_version_id;

  -- Update operator last static import timestamp
  update public.transport_operators
  set last_static_import_at = now(),
      updated_at = now()
  where id = v_operator_id;

  return true;
end;
$$ language plpgsql security definer set search_path = public;

-- ==============================================================================
-- 9. USER-FACING / MOBILE OPTIMIZED VIEWS
-- ==============================================================================

create or replace view public.v_active_stops as
select
  s.id,
  s.feed_version_id,
  s.operator_id,
  o.normalized_name as operator_name,
  o.slug as operator_slug,
  s.external_stop_id,
  s.stop_name,
  s.stop_code,
  s.latitude,
  s.longitude,
  sp.province_code,
  p.name_es as province_name
from public.gtfs_stops s
join public.feed_versions f on f.id = s.feed_version_id and f.status = 'active'
join public.transport_operators o on o.id = s.operator_id
left join public.stop_provinces sp on sp.stop_id = s.id
left join public.provinces p on p.code = sp.province_code;

create or replace view public.v_active_routes as
select
  r.id,
  r.feed_version_id,
  r.operator_id,
  o.normalized_name as operator_name,
  o.slug as operator_slug,
  r.external_route_id,
  r.route_short_name,
  r.route_long_name,
  r.route_type,
  r.route_color,
  r.route_text_color,
  array_agg(distinct rp.province_code) as provinces_served
from public.gtfs_routes r
join public.feed_versions f on f.id = r.feed_version_id and f.status = 'active'
join public.transport_operators o on o.id = r.operator_id
left join public.route_provinces rp on rp.route_id = r.id
group by r.id, r.feed_version_id, r.operator_id, o.normalized_name, o.slug, r.external_route_id, r.route_short_name, r.route_long_name, r.route_type, r.route_color, r.route_text_color;

create or replace view public.v_active_vehicles as
select distinct on (vp.operator_id, vp.vehicle_id)
  vp.id,
  vp.operator_id,
  o.normalized_name as operator_name,
  o.slug as operator_slug,
  vp.vehicle_id,
  vp.vehicle_label,
  vp.external_trip_id,
  vp.external_route_id,
  r.route_short_name,
  r.route_color,
  vp.latitude,
  vp.longitude,
  vp.bearing,
  vp.speed,
  vp.current_status,
  vp.timestamp
from public.vehicle_positions vp
join public.transport_operators o on o.id = vp.operator_id
left join public.gtfs_routes r on r.id = vp.route_id
where vp.is_latest = true
order by vp.operator_id, vp.vehicle_id, vp.timestamp desc;

-- ==============================================================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

alter table public.provinces enable row level security;
alter table public.administrative_boundaries enable row level security;
alter table public.municipalities enable row level security;
alter table public.transport_modes enable row level security;
alter table public.transport_operators enable row level security;
alter table public.operator_provinces enable row level security;
alter table public.operator_transport_modes enable row level security;
alter table public.catalogue_snapshots enable row level security;
alter table public.catalogue_resources enable row level security;
alter table public.feed_versions enable row level security;
alter table public.ingestion_jobs enable row level security;
alter table public.ingestion_errors enable row level security;
alter table public.gtfs_agencies enable row level security;
alter table public.gtfs_stops enable row level security;
alter table public.stop_provinces enable row level security;
alter table public.gtfs_routes enable row level security;
alter table public.route_provinces enable row level security;
alter table public.gtfs_calendars enable row level security;
alter table public.gtfs_calendar_dates enable row level security;
alter table public.gtfs_shapes enable row level security;
alter table public.gtfs_trips enable row level security;
alter table public.gtfs_stop_times enable row level security;
alter table public.gtfs_frequencies enable row level security;
alter table public.gtfs_transfers enable row level security;
alter table public.gtfs_attributions enable row level security;
alter table public.realtime_feed_snapshots enable row level security;
alter table public.vehicle_positions enable row level security;
alter table public.trip_updates enable row level security;
alter table public.stop_time_updates enable row level security;
alter table public.service_alerts enable row level security;
alter table public.alert_informed_entities enable row level security;
alter table public.siri_vehicle_observations enable row level security;
alter table public.siri_situation_exchanges enable row level security;
alter table public.netex_resources enable row level security;
alter table public.spatial_resources enable row level security;

-- Public Read Policies for Static Transit & Geographies
create policy "Public can read provinces" on public.provinces for select using (true);
create policy "Public can read administrative boundaries" on public.administrative_boundaries for select using (true);
create policy "Public can read municipalities" on public.municipalities for select using (true);
create policy "Public can read transport modes" on public.transport_modes for select using (true);
create policy "Public can read active operators" on public.transport_operators for select using (is_active = true);
create policy "Public can read operator provinces" on public.operator_provinces for select using (true);
create policy "Public can read operator transport modes" on public.operator_transport_modes for select using (true);
create policy "Public can read active feed versions" on public.feed_versions for select using (status = 'active');
create policy "Public can read active gtfs stops" on public.gtfs_stops for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active stop provinces" on public.stop_provinces for select using (true);
create policy "Public can read active gtfs routes" on public.gtfs_routes for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active route provinces" on public.route_provinces for select using (true);
create policy "Public can read active gtfs trips" on public.gtfs_trips for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active gtfs stop times" on public.gtfs_stop_times for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active gtfs calendars" on public.gtfs_calendars for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active gtfs calendar dates" on public.gtfs_calendar_dates for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active gtfs shapes" on public.gtfs_shapes for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);
create policy "Public can read active attributions" on public.gtfs_attributions for select using (
  exists (select 1 from public.feed_versions f where f.id = feed_version_id and f.status = 'active')
);

-- Public Read Policies for Real-Time Telemetry
create policy "Public can read latest vehicle positions" on public.vehicle_positions for select using (is_latest = true);
create policy "Public can read active trip updates" on public.trip_updates for select using (true);
create policy "Public can read stop time updates" on public.stop_time_updates for select using (true);
create policy "Public can read active service alerts" on public.service_alerts for select using (is_active = true);
create policy "Public can read alert informed entities" on public.alert_informed_entities for select using (true);

-- Ingestion Pipeline (Service Role) Full CRUD Policies
create policy "Service role full access on all tables" on public.provinces for all using (auth.role() = 'service_role');
create policy "Service role full access on administrative boundaries" on public.administrative_boundaries for all using (auth.role() = 'service_role');
create policy "Service role full access on municipalities" on public.municipalities for all using (auth.role() = 'service_role');
create policy "Service role full access on transport operators" on public.transport_operators for all using (auth.role() = 'service_role');
create policy "Service role full access on operator provinces" on public.operator_provinces for all using (auth.role() = 'service_role');
create policy "Service role full access on operator transport modes" on public.operator_transport_modes for all using (auth.role() = 'service_role');
create policy "Service role full access on catalogue snapshots" on public.catalogue_snapshots for all using (auth.role() = 'service_role');
create policy "Service role full access on catalogue resources" on public.catalogue_resources for all using (auth.role() = 'service_role');
create policy "Service role full access on feed versions" on public.feed_versions for all using (auth.role() = 'service_role');
create policy "Service role full access on ingestion jobs" on public.ingestion_jobs for all using (auth.role() = 'service_role');
create policy "Service role full access on ingestion errors" on public.ingestion_errors for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs agencies" on public.gtfs_agencies for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs stops" on public.gtfs_stops for all using (auth.role() = 'service_role');
create policy "Service role full access on stop provinces" on public.stop_provinces for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs routes" on public.gtfs_routes for all using (auth.role() = 'service_role');
create policy "Service role full access on route provinces" on public.route_provinces for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs calendars" on public.gtfs_calendars for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs calendar dates" on public.gtfs_calendar_dates for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs shapes" on public.gtfs_shapes for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs trips" on public.gtfs_trips for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs stop times" on public.gtfs_stop_times for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs frequencies" on public.gtfs_frequencies for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs transfers" on public.gtfs_transfers for all using (auth.role() = 'service_role');
create policy "Service role full access on gtfs attributions" on public.gtfs_attributions for all using (auth.role() = 'service_role');
create policy "Service role full access on realtime snapshots" on public.realtime_feed_snapshots for all using (auth.role() = 'service_role');
create policy "Service role full access on vehicle positions" on public.vehicle_positions for all using (auth.role() = 'service_role');
create policy "Service role full access on trip updates" on public.trip_updates for all using (auth.role() = 'service_role');
create policy "Service role full access on stop time updates" on public.stop_time_updates for all using (auth.role() = 'service_role');
create policy "Service role full access on service alerts" on public.service_alerts for all using (auth.role() = 'service_role');
create policy "Service role full access on alert informed entities" on public.alert_informed_entities for all using (auth.role() = 'service_role');
create policy "Service role full access on siri observations" on public.siri_vehicle_observations for all using (auth.role() = 'service_role');
create policy "Service role full access on siri situations" on public.siri_situation_exchanges for all using (auth.role() = 'service_role');
create policy "Service role full access on netex resources" on public.netex_resources for all using (auth.role() = 'service_role');
create policy "Service role full access on spatial resources" on public.spatial_resources for all using (auth.role() = 'service_role');
