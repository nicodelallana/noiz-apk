"""Automated scheduler runner configuring periodic jobs."""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger

from src.config import settings
from src.normalizer.pipeline import IngestionPipeline
from src.utils.logging import logger


class IngestionScheduler:
    """Manages recurring automated ingestion tasks."""

    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.pipeline = IngestionPipeline()

    def start(self):
        """Starts all scheduled transport ingestion tasks."""
        logger.info("Initializing Moveuskadi ingestion scheduler...")

        # 1. Dynamic Catalogue Discovery (every 15 min default)
        self.scheduler.add_job(
            func=self.pipeline.run_catalogue_discovery,
            trigger=IntervalTrigger(minutes=settings.CATALOG_DISCOVERY_INTERVAL_MINUTES),
            id="job_catalogue_discovery",
            name="Moveuskadi Catalogue Discovery",
            replace_existing=True
        )

        # Start background executor
        self.scheduler.start()
        logger.info(
            f"Scheduler started: Catalogue discovery scheduled every "
            f"{settings.CATALOG_DISCOVERY_INTERVAL_MINUTES} minutes."
        )

    def shutdown(self):
        """Gracefully shuts down scheduler."""
        logger.info("Shutting down ingestion scheduler...")
        self.scheduler.shutdown(wait=False)
