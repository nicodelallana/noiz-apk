"""Supabase Storage manager for Moveuskadi transit resources."""

import os
import shutil
from datetime import datetime, timezone
from typing import Optional
from src.config import settings
from src.utils.logging import logger

try:
    from supabase import create_client, Client
except ImportError:
    create_client = None
    Client = None


class SupabaseStorageService:
    """Uploads and archives snapshots, raw feeds, and processed bundles in Supabase Storage."""

    def __init__(
        self,
        supabase_url: Optional[str] = None,
        service_role_key: Optional[str] = None,
        bucket_name: Optional[str] = None,
        local_fallback_dir: Optional[str] = None
    ):
        self.supabase_url = supabase_url or settings.SUPABASE_URL
        self.service_role_key = service_role_key or settings.SUPABASE_SERVICE_ROLE_KEY
        self.bucket_name = bucket_name or settings.SUPABASE_STORAGE_BUCKET
        self.local_fallback_dir = local_fallback_dir or os.path.join(settings.DATA_DIR, "storage_archive")
        os.makedirs(self.local_fallback_dir, exist_ok=True)

        self.client: Optional[Client] = None
        if create_client and self.supabase_url and self.service_role_key:
            try:
                self.client = create_client(self.supabase_url, self.service_role_key)
                logger.info(f"Supabase Storage initialized on bucket: {self.bucket_name}")
            except Exception as e:
                logger.warning(f"Could not connect to Supabase Storage client: {e}")

    def upload_file(
        self,
        local_path: str,
        storage_path: str,
        content_type: str = "application/octet-stream"
    ) -> str:
        """Uploads a file to Supabase Storage or falls back to local archive if unconfigured."""
        if not os.path.exists(local_path):
            raise FileNotFoundError(f"Local file does not exist: {local_path}")

        # Always maintain local copy in fallback directory for auditability
        archive_dest = os.path.join(self.local_fallback_dir, storage_path)
        os.makedirs(os.path.dirname(archive_dest), exist_ok=True)
        shutil.copy2(local_path, archive_dest)

        if self.client:
            try:
                with open(local_path, "rb") as f:
                    self.client.storage.from_(self.bucket_name).upload(
                        path=storage_path,
                        file=f,
                        file_options={"content-type": content_type, "upsert": "true"}
                    )
                logger.info(f"Uploaded to Supabase Storage: {self.bucket_name}/{storage_path}")
                return f"{self.supabase_url}/storage/v1/object/public/{self.bucket_name}/{storage_path}"
            except Exception as e:
                logger.error(f"Supabase storage upload failed for {storage_path}: {e}")

        return f"file://{archive_dest}"

    def upload_catalogue_snapshot(self, snapshot_bytes: bytes, checksum: str) -> str:
        """Stores a snapshot of data-index.json."""
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        date_folder = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        storage_path = f"moveuskadi/catalogue/snapshots/{date_folder}/{timestamp}_{checksum[:8]}.json"

        temp_path = os.path.join(self.local_fallback_dir, f"snap_{timestamp}.json")
        with open(temp_path, "wb") as f:
            f.write(snapshot_bytes)

        url = self.upload_file(temp_path, storage_path, content_type="application/json")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return url

    def upload_raw_resource(
        self,
        local_path: str,
        operator_slug: str,
        filename: str,
        province: str = "shared"
    ) -> str:
        """Stores a raw resource (GTFS, GTFS-RT, SIRI, NeTEx) with versioned timestamp."""
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        storage_path = f"moveuskadi/raw/{province}/{operator_slug}/{timestamp}_{filename}"
        return self.upload_file(local_path, storage_path)
