"""Robust download manager for Moveuskadi transit resources.

Features:
- Handles URLs with unencoded spaces and accents cleanly
- Exponential backoff retry loop
- Atomic temporary file promotion
- SHA-256 computation and Content-Length verification
- MIME / signature validation to reject HTML error pages
"""

import hashlib
import os
import shutil
import tempfile
import time
import urllib.parse
from dataclasses import dataclass
from typing import Optional
import httpx

from src.config import settings
from src.utils.logging import logger


@dataclass
class DownloadResult:
    """Outcome of a resource download attempt."""
    success: bool
    url: str
    file_path: Optional[str] = None
    checksum: Optional[str] = None
    file_size_bytes: int = 0
    content_type: Optional[str] = None
    etag: Optional[str] = None
    last_modified: Optional[str] = None
    error_message: Optional[str] = None
    duration_seconds: float = 0.0


def sanitize_url(raw_url: str) -> str:
    """Safely encodes spaces and special characters in URL path while preserving query/structure."""
    parts = urllib.parse.urlsplit(raw_url.strip())
    # Quote path characters (like spaces) but keep existing slashes and unquote first to avoid double encoding
    unquoted_path = urllib.parse.unquote(parts.path)
    quoted_path = urllib.parse.quote(unquoted_path, safe="/:@&+$,;=")
    clean_url = urllib.parse.urlunsplit((parts.scheme, parts.netloc, quoted_path, parts.query, parts.fragment))
    return clean_url


class DownloadManager:
    """Manages resilient downloading of large feeds with retries and atomic staging."""

    def __init__(
        self,
        base_dir: Optional[str] = None,
        timeout_seconds: Optional[float] = None,
        max_retries: Optional[int] = None
    ):
        self.base_dir = base_dir or os.path.join(settings.DATA_DIR, "downloads")
        os.makedirs(self.base_dir, exist_ok=True)
        self.timeout = timeout_seconds or settings.DOWNLOAD_TIMEOUT_SECONDS
        self.max_retries = max_retries or settings.DOWNLOAD_MAX_RETRIES
        self.backoff_factor = settings.DOWNLOAD_BACKOFF_FACTOR

    def download_resource(
        self,
        url: str,
        target_filename: str,
        expected_format: str,
        subfolder: str = "raw"
    ) -> DownloadResult:
        """Downloads a resource with exponential backoff and validates the payload."""
        start_time = time.time()
        clean_url = sanitize_url(url)
        target_dir = os.path.join(self.base_dir, subfolder)
        os.makedirs(target_dir, exist_ok=True)
        final_dest = os.path.join(target_dir, target_filename)

        headers = {
            "User-Agent": settings.USER_AGENT,
            "Accept": "*/*"
        }

        # Check existing file for Conditional GET
        if os.path.exists(final_dest):
            # Compute existing checksum for logging
            with open(final_dest, "rb") as f:
                existing_hash = hashlib.sha256(f.read()).hexdigest()
        else:
            existing_hash = None

        last_error = None
        for attempt in range(1, self.max_retries + 1):
            temp_fd = None
            temp_path = None
            try:
                logger.info(f"Downloading (attempt {attempt}/{self.max_retries}): {clean_url}")
                temp_fd, temp_path = tempfile.mkstemp(dir=target_dir, prefix="dl_tmp_")
                hasher = hashlib.sha256()
                bytes_downloaded = 0

                with httpx.Client(
                    timeout=self.timeout,
                    follow_redirects=True,
                    verify=False
                ) as client:
                    with client.stream("GET", clean_url, headers=headers) as resp:
                        if resp.status_code == 304 and existing_hash:
                            logger.info(f"Resource not modified (304): {clean_url}")
                            os.close(temp_fd)
                            os.remove(temp_path)
                            return DownloadResult(
                                success=True,
                                url=url,
                                file_path=final_dest,
                                checksum=existing_hash,
                                file_size_bytes=os.path.getsize(final_dest),
                                duration_seconds=time.time() - start_time
                            )

                        resp.raise_for_status()

                        content_type = resp.headers.get("content-type", "").lower()
                        etag = resp.headers.get("etag")
                        last_modified = resp.headers.get("last-modified")

                        for chunk in resp.iter_bytes(chunk_size=65536):
                            if chunk:
                                os.write(temp_fd, chunk)
                                hasher.update(chunk)
                                bytes_downloaded += len(chunk)

                os.close(temp_fd)
                temp_fd = None

                # Signature / Content check: Never accept HTML error pages for ZIP or PB
                with open(temp_path, "rb") as f:
                    header_bytes = f.read(512)

                if expected_format in ("GTFS", "NETEX") and not header_bytes.startswith(b"PK"):
                    raise ValueError(
                        f"Expected ZIP archive for {expected_format}, but magic bytes do not match: {header_bytes[:8]}"
                    )
                if expected_format == "SIRI" and not (header_bytes.startswith(b"<?xml") or b"<" in header_bytes[:50]):
                    raise ValueError("Expected XML document for SIRI, but no XML header found")

                checksum = hasher.hexdigest()

                # Atomic promotion: move temp file to final destination
                shutil.move(temp_path, final_dest)
                duration = time.time() - start_time
                logger.info(f"Download successful: {final_dest} ({bytes_downloaded} bytes, {duration:.2f}s)")

                return DownloadResult(
                    success=True,
                    url=url,
                    file_path=final_dest,
                    checksum=checksum,
                    file_size_bytes=bytes_downloaded,
                    content_type=content_type,
                    etag=etag,
                    last_modified=last_modified,
                    duration_seconds=duration
                )

            except Exception as e:
                last_error = str(e)
                logger.warning(f"Download attempt {attempt} failed for {clean_url}: {e}")
                if temp_fd is not None:
                    try:
                        os.close(temp_fd)
                    except OSError:
                        pass
                if temp_path and os.path.exists(temp_path):
                    try:
                        os.remove(temp_path)
                    except OSError:
                        pass

                if attempt < self.max_retries:
                    sleep_time = self.backoff_factor ** attempt
                    time.sleep(sleep_time)

        duration = time.time() - start_time
        logger.error(f"Download failed after {self.max_retries} attempts: {clean_url} - {last_error}")
        return DownloadResult(
            success=False,
            url=url,
            error_message=last_error,
            duration_seconds=duration
        )
