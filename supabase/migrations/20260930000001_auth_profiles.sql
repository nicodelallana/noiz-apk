-- Migration: 20260930000001_auth_profiles.sql
-- Description: Automatic profile provisioning trigger and self-service account deletion RPC for compliance.

-- 1. Add avatar_url to public.profiles if not present
alter table public.profiles add column if not exists avatar_url text;

-- 2. Trigger function to automatically create/update profile when auth.users is created
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name, avatar_url, created_at)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url',
    now()
  )
  on conflict (id) do update
  set
    display_name = coalesce(excluded.display_name, profiles.display_name),
    avatar_url = coalesce(excluded.avatar_url, profiles.avatar_url);
  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Drop existing trigger if any and recreate
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute function public.handle_new_user();

-- 3. Self-service Account Deletion RPC
-- Required by Apple App Store Guideline 5.1.1(v) and Google Play account deletion policy.
-- Executed with security definer to allow the authenticated user to delete their own account.
create or replace function public.delete_user_account()
returns void as $$
begin
  -- Deleting the user in auth.users automatically triggers cascade deletion
  -- for profiles, saved_trips, trip_shares, and user_settings.
  delete from auth.users where id = auth.uid();
end;
$$ language plpgsql security definer set search_path = public;

revoke all on function public.delete_user_account() from public;
grant execute on function public.delete_user_account() to authenticated;
