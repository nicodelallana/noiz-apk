"""FastAPI monitoring and management server."""

from contextlib import asynccontextmanager
from typing import Any, Dict, List
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from src.catalog.discovery import CatalogueDiscoveryService
from src.db.connection import check_database_health
from src.normalizer.pipeline import IngestionPipeline
from src.scheduler.runner import IngestionScheduler
from src.utils.logging import logger

pipeline = IngestionPipeline()
scheduler = IngestionScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start scheduler
    logger.info("FastAPI monitoring application starting...")
    scheduler.start()
    yield
    # Shutdown
    scheduler.shutdown()
    logger.info("FastAPI application stopped.")


app = FastAPI(
    title="Moveuskadi Transport Ingestion Platform API",
    description="Automated public transport discovery, ingestion, and telemetry monitoring for the Basque Country.",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)


@app.get("/health", tags=["Monitoring"])
def get_health() -> Dict[str, Any]:
    """Health check for service, database, and scheduler."""
    db_healthy = check_database_health()
    return {
        "status": "healthy" if db_healthy else "degraded",
        "service": "moveuskadi-ingestion",
        "database_connected": db_healthy,
        "scheduler_running": scheduler.scheduler.running
    }


@app.get("/operators", tags=["Catalog"])
def list_operators() -> Dict[str, Any]:
    """Retrieves discovered operators directly from live catalogue."""
    try:
        snapshot, catalogs = pipeline.discovery_service.fetch_catalogue()
        return {
            "total_operators": snapshot.total_operators,
            "total_resources": snapshot.total_resources,
            "catalogue_last_update": snapshot.catalogue_last_update,
            "operators": [
                {
                    "name": op.original_name,
                    "normalized": op.normalized_name,
                    "slug": op.slug,
                    "formats": op.available_formats,
                    "resource_count": len(op.resources)
                }
                for op in catalogs.values()
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@app.post("/trigger/discovery", tags=["Orchestration"])
def trigger_discovery() -> Dict[str, Any]:
    """Manually triggers catalogue discovery."""
    try:
        res = pipeline.run_catalogue_discovery()
        return res
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
