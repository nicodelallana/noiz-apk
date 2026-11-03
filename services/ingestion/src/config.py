"""Global configuration settings for the Moveuskadi ingestion platform."""

import os
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    # Environment
    ENVIRONMENT: str = "production"
    LOG_LEVEL: str = "INFO"

    # Moveuskadi & Open Data Euskadi Endpoints
    MOVEUSKADI_CATALOG_URL: str = "https://opendata.euskadi.eus/transport/moveuskadi/data-index.json"
    MOVEUSKADI_CATALOGUE_PAGE_URL: str = (
        "https://opendata.euskadi.eus/catalogo/-/"
        "moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-"
        "operadores-horarios-paradas-calendario-tarifas-etc/"
    )
    GEOEUSKADI_TERRITORIOS_URL: str = (
        "https://www.geo.euskadi.eus/cartografia/DatosDescarga/Limites/TERRITORIOS_5000_ETRS89.zip"
    )
    GEOEUSKADI_MUNICIPIOS_URL: str = (
        "https://www.geo.euskadi.eus/cartografia/DatosDescarga/Limites/MUNICIPIOS_5000_ETRS89.zip"
    )

    # Supabase PostgreSQL Database (with PostGIS)
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/postgres"
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20

    # Supabase API & Storage
    SUPABASE_URL: str = "https://ocxcrxgagennmukuxnle.supabase.co"
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""
    SUPABASE_STORAGE_BUCKET: str = "transit-packs"

    # Download Engine Settings
    DOWNLOAD_TIMEOUT_SECONDS: float = 60.0
    DOWNLOAD_MAX_RETRIES: int = 3
    DOWNLOAD_BACKOFF_FACTOR: float = 1.5
    MAX_CONCURRENT_DOWNLOADS: int = 5
    USER_AGENT: str = "MoveuskadiTransitBot/1.0 (+https://github.com/bizkaia-transit)"
    DATA_DIR: str = os.path.join(os.getcwd(), "data")

    # Automated Scheduling Settings
    CATALOG_DISCOVERY_INTERVAL_MINUTES: int = 15
    STATIC_CHECK_INTERVAL_HOURS: int = 6
    REALTIME_VEHICLES_INTERVAL_SECONDS: int = 20
    REALTIME_TRIP_UPDATES_INTERVAL_SECONDS: int = 45
    REALTIME_ALERTS_INTERVAL_MINUTES: int = 2

    # Monitoring API Server
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000


settings = Settings()
