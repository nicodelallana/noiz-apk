-- ==============================================================================
-- BIZKAIA TRANSIT - COMPLETE SUPABASE SETUP (Idempotent & Ready to Run)
-- Project Ref: ocxcrxgagennmukuxnle
-- ==============================================================================

-- 1. Profiles Table (1:1 with auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 60),
  avatar_url text,
  created_at timestamptz not null default now()
);

-- 2. Saved Trips Table (Supports all 13 Euskadi Operators)
create table if not exists public.saved_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  operator text not null check (
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
  ),
  origin_stop_id text not null,
  dest_stop_id text not null,
  route_id text,
  direction_id smallint check (direction_id in (0,1)),
  widget_enabled boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_saved_trips_user_order on public.saved_trips (user_id, sort_order);

-- 3. Short-lived Trip Share Codes (8-character alphanumeric)
create table if not exists public.trip_shares (
  code text primary key check (code ~ '^[A-Z2-9]{8}$'),
  trip_id uuid not null references public.saved_trips(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);

-- 4. User Settings
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  barik_balance_cents int check (barik_balance_cents >= 0),
  barik_balance_updated_at timestamptz,
  language text default 'es' check (language in ('es','eu','en'))
);

-- 5. Live Trip Sessions (for Dynamic Island & Lock-Screen Push Dispatching)
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

-- 6. Service Alerts Table for Euskadi Incidents Cache
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

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
alter table public.profiles           enable row level security;
alter table public.saved_trips        enable row level security;
alter table public.trip_shares        enable row level security;
alter table public.user_settings      enable row level security;
alter table public.live_trip_sessions enable row level security;
alter table public.service_alerts     enable row level security;

-- Profiles Policies
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());

-- Saved Trips Policies
drop policy if exists "own trips" on public.saved_trips;
create policy "own trips" on public.saved_trips for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Trip Shares Policies
drop policy if exists "own shares" on public.trip_shares;
create policy "own shares" on public.trip_shares for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- User Settings Policies
drop policy if exists "own settings" on public.user_settings;
create policy "own settings" on public.user_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Live Trip Sessions Policies
drop policy if exists "allow_select_own_sessions" on public.live_trip_sessions;
create policy "allow_select_own_sessions" on public.live_trip_sessions for select using (
  (auth.uid() is not null and user_id = auth.uid()) or
  (device_id = current_setting('request.headers', true)::json->>'x-device-id')
);

drop policy if exists "allow_insert_own_sessions" on public.live_trip_sessions;
create policy "allow_insert_own_sessions" on public.live_trip_sessions for insert with check (
  (auth.uid() is not null and user_id = auth.uid()) or
  (device_id is not null)
);

drop policy if exists "allow_update_own_sessions" on public.live_trip_sessions;
create policy "allow_update_own_sessions" on public.live_trip_sessions for update using (
  (auth.uid() is not null and user_id = auth.uid()) or
  (device_id = current_setting('request.headers', true)::json->>'x-device-id')
);

drop policy if exists "allow_delete_own_sessions" on public.live_trip_sessions;
create policy "allow_delete_own_sessions" on public.live_trip_sessions for delete using (
  (auth.uid() is not null and user_id = auth.uid()) or
  (device_id = current_setting('request.headers', true)::json->>'x-device-id')
);

-- Service Alerts Policies
drop policy if exists "public_read_alerts" on public.service_alerts;
create policy "public_read_alerts" on public.service_alerts for select using (true);

-- ==============================================================================
-- STORAGE BUCKETS (Public bucket for offline GTFS SQLite bundles)
-- ==============================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'transit-packs',
  'transit-packs',
  true,
  52428800, -- 50 MB
  array['application/gzip', 'application/json', 'application/x-sqlite3', 'application/octet-stream']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 52428800;

drop policy if exists "Public Access to Transit Packs" on storage.objects;
create policy "Public Access to Transit Packs" on storage.objects for select using ( bucket_id = 'transit-packs' );

drop policy if exists "Service Role Uploads to Transit Packs" on storage.objects;
create policy "Service Role Uploads to Transit Packs" on storage.objects for all
  using ( bucket_id = 'transit-packs' and auth.role() = 'service_role' )
  with check ( bucket_id = 'transit-packs' and auth.role() = 'service_role' );

-- ==============================================================================
-- RPC FUNCTIONS & TRIGGERS
-- ==============================================================================

-- 1. Redeem trip share anonymously
create or replace function public.redeem_trip_share(p_code text)
returns table (
  name text,
  operator text,
  origin_stop_id text,
  dest_stop_id text,
  route_id text,
  direction_id smallint
)
language sql security definer set search_path = public as $$
  select t.name, t.operator, t.origin_stop_id, t.dest_stop_id, t.route_id, t.direction_id
  from trip_shares s join saved_trips t on t.id = s.trip_id
  where s.code = upper(p_code) and s.expires_at > now();
$$;

revoke all on function public.redeem_trip_share(text) from public;
grant execute on function public.redeem_trip_share(text) to authenticated;

-- 2. Automatic profile provisioning on sign-up / login
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update set
    display_name = coalesce(excluded.display_name, profiles.display_name),
    avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url);
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute function public.handle_new_user();

-- 3. Self-service Account Deletion (Apple/Google policy compliance)
create or replace function public.delete_user_account()
returns void as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.delete_user_account() from public;
grant execute on function public.delete_user_account() to authenticated;

-- 4. Prune stale sessions older than 4 hours
create or replace function public.prune_stale_live_trips()
returns void as $$
begin
  delete from public.live_trip_sessions
  where updated_at < (now() - interval '4 hours')
     or status = 'ended';
end;
$$ language plpgsql security definer;
