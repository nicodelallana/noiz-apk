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
  primary_color text not null default '#025DA9',
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
