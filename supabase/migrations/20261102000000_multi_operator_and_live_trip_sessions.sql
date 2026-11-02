-- Migration: 20261102000000_multi_operator_and_live_trip_sessions.sql
-- Description: Multi-operator support for all 13 Euskadi services, live trip session tracking with RLS, and service alerts cache.

-- 1. Expand saved_trips operator check constraint
alter table public.saved_trips drop constraint if exists saved_trips_operator_check;
alter table public.saved_trips add constraint saved_trips_operator_check check (
  operator in (
    'metro',
    'renfe',
    'euskotren',
    'tranbia_bilbao',
    'tranbia_gasteiz',
    'bizkaibus',
    'bilbobus',
    'dbus',
    'lurraldebus',
    'tuvisa',
    'alavabus',
    'artxanda',
    'la_union'
  )
);

-- 2. Live Trip Sessions for lock-screen push dispatching
create table if not exists public.live_trip_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  device_id text not null,
  operator_id text not null,
  trip_id text not null,
  line_name text not null,
  line_color text not null default '#E2001A',
  origin text not null,
  destination text not null,
  fcm_token text,
  apns_token text,
  status text not null default 'tracking' check (status in ('scheduled', 'tracking', 'arriving', 'at_stop', 'delayed', 'disrupted', 'ended')),
  current_progress double precision not null default 0.0,
  arrival_time timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_live_trip_sessions_device on public.live_trip_sessions (device_id);
create index if not exists idx_live_trip_sessions_status on public.live_trip_sessions (status);

-- Enable RLS
alter table public.live_trip_sessions enable row level security;

-- Policies for live_trip_sessions
create policy "allow_select_own_sessions" on public.live_trip_sessions
  for select using (
    (auth.uid() is not null and user_id = auth.uid()) or
    (device_id = current_setting('request.headers', true)::json->>'x-device-id')
  );

create policy "allow_insert_own_sessions" on public.live_trip_sessions
  for insert with check (
    (auth.uid() is not null and user_id = auth.uid()) or
    (device_id is not null)
  );

create policy "allow_update_own_sessions" on public.live_trip_sessions
  for update using (
    (auth.uid() is not null and user_id = auth.uid()) or
    (device_id = current_setting('request.headers', true)::json->>'x-device-id')
  );

create policy "allow_delete_own_sessions" on public.live_trip_sessions
  for delete using (
    (auth.uid() is not null and user_id = auth.uid()) or
    (device_id = current_setting('request.headers', true)::json->>'x-device-id')
  );

-- 3. Service Alerts Table for Euskadi Incidents Cache
create table if not exists public.service_alerts (
  id uuid primary key default gen_random_uuid(),
  operator_id text not null,
  territory text not null check (territory in ('bizkaia', 'gipuzkoa', 'araba', 'all')),
  line_id text,
  severity text not null check (severity in ('info', 'warning', 'severe')),
  title text not null,
  description text not null,
  active_period_start timestamptz,
  active_period_end timestamptz,
  created_at timestamptz not null default now()
);

alter table public.service_alerts enable row level security;
create policy "public_read_alerts" on public.service_alerts for select using (true);

-- 4. Auto-prune stale sessions older than 4 hours
create or replace function public.prune_stale_live_trips()
returns void as $$
begin
  delete from public.live_trip_sessions
  where updated_at < (now() - interval '4 hours')
     or status = 'ended';
end;
$$ language plpgsql security definer;
