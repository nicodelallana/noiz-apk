-- Migration: 20260929000000_initial_schema.sql
-- Description: Baseline user schema with Row Level Security (RLS) and redeem_trip_share function.

-- 1. Profiles (1:1 with auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 60),
  created_at timestamptz not null default now()
);

-- 2. Saved Trips
create table public.saved_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  operator text not null check (operator in ('metro','bizkaibus','bilbobus','euskotren','renfe')),
  origin_stop_id text not null,
  dest_stop_id text not null,
  route_id text,
  direction_id smallint check (direction_id in (0,1)),
  widget_enabled boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.saved_trips (user_id, sort_order);

-- 3. Short-lived Trip Share Codes
create table public.trip_shares (
  code text primary key check (code ~ '^[A-Z2-9]{8}$'),
  trip_id uuid not null references public.saved_trips(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now()
);

-- 4. User Settings
create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  barik_balance_cents int check (barik_balance_cents >= 0),
  barik_balance_updated_at timestamptz,
  language text default 'es' check (language in ('es','eu','en'))
);

-- 5. Row Level Security Policies
alter table public.profiles       enable row level security;
alter table public.saved_trips    enable row level security;
alter table public.trip_shares    enable row level security;
alter table public.user_settings  enable row level security;

create policy "own profile"  on public.profiles      for all using (id = auth.uid())       with check (id = auth.uid());
create policy "own trips"    on public.saved_trips   for all using (user_id = auth.uid())  with check (user_id = auth.uid());
create policy "own shares"   on public.trip_shares   for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "own settings" on public.user_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 6. RPC Function for Safe Trip Redemption (Hides owner identity)
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
