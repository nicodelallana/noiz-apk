-- Migration: 20260929000001_transit_storage_bucket.sql
-- Description: Create public storage bucket 'transit-packs' for offline SQLite bundles and manifest.json.

-- 1. Create the transit-packs bucket
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

-- 2. Read-only policy for public unauthenticated access
create policy "Public Access to Transit Packs"
  on storage.objects for select
  using ( bucket_id = 'transit-packs' );

-- 3. Management policy for service_role (GitHub Actions ETL uploader)
create policy "Service Role Uploads to Transit Packs"
  on storage.objects for all
  using ( bucket_id = 'transit-packs' and auth.role() = 'service_role' )
  with check ( bucket_id = 'transit-packs' and auth.role() = 'service_role' );
