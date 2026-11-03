"""SQLAlchemy database engine and session management."""

from contextlib import contextmanager
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session

from src.config import settings
from src.utils.logging import logger

Base = declarative_base()

try:
    engine = create_engine(
        settings.DATABASE_URL,
        pool_size=settings.DATABASE_POOL_SIZE,
        max_overflow=settings.DATABASE_MAX_OVERFLOW,
        pool_pre_ping=True
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
except Exception as e:
    logger.warning(f"Could not initialize SQLAlchemy engine with {settings.DATABASE_URL}: {e}")
    engine = None
    SessionLocal = None


@contextmanager
def get_db_session() -> Generator[Session, None, None]:
    """Provides a transactional database session."""
    if SessionLocal is None:
        raise RuntimeError("Database session factory is not initialized. Check DATABASE_URL.")
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        logger.error(f"Database session error, rolled back: {e}")
        raise
    finally:
        session.close()


def check_database_health() -> bool:
    """Verifies database connectivity and PostGIS extension."""
    if engine is None:
        return False
    try:
        with engine.connect() as conn:
            res = conn.execute(text("SELECT postgis_version();")).scalar()
            logger.info(f"Connected to PostgreSQL with PostGIS: {res}")
            return True
    except Exception as e:
        logger.warning(f"Database healthcheck failed: {e}")
        return False
