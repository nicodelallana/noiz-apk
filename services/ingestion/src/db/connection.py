"""SQLAlchemy database engine and session management."""

import urllib.parse
from contextlib import contextmanager
from typing import Generator
from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker, Session

from src.config import settings
from src.utils.logging import logger

Base = declarative_base()


def _normalize_supabase_url(db_url: str) -> str:
    """Normalizes postgres URLs and fixes Supabase pooler username requirement."""
    if not db_url:
        return ""
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)

    if "[YOUR-PASSWORD]" in db_url or "[your-password]" in db_url:
        logger.error(
            "DATABASE_URL contains literal placeholder '[YOUR-PASSWORD]'. "
            "Please replace it with your actual Supabase database password in GitHub Secrets."
        )

    try:
        parsed = urllib.parse.urlparse(db_url)
        hostname = parsed.hostname or ""
        # Supabase pooler requires username in the format postgres.<project-ref>
        if "pooler.supabase.com" in hostname and parsed.username == "postgres":
            project_ref = ""
            if settings.SUPABASE_URL:
                sb_parsed = urllib.parse.urlparse(settings.SUPABASE_URL)
                project_ref = (sb_parsed.hostname or "").split(".")[0]
            if project_ref:
                logger.info(f"Auto-formatting pooler username to postgres.{project_ref}")
                port_str = f":{parsed.port}" if parsed.port else ""
                pwd_str = f":{parsed.password}" if parsed.password is not None else ""
                netloc = f"postgres.{project_ref}{pwd_str}@{hostname}{port_str}"
                db_url = urllib.parse.urlunparse((parsed.scheme, netloc, parsed.path, parsed.params, parsed.query, parsed.fragment))
    except Exception as e:
        logger.debug(f"URL parsing note: {e}")

    return db_url


def _create_robust_engine():
    raw_url = settings.DATABASE_URL
    if not raw_url:
        return None

    db_url = _normalize_supabase_url(raw_url)

    errors = []
    # Strategy 1: Standard URL
    try:
        return create_engine(
            db_url,
            pool_size=settings.DATABASE_POOL_SIZE,
            max_overflow=settings.DATABASE_MAX_OVERFLOW,
            pool_pre_ping=True
        )
    except Exception as e1:
        errors.append(f"default ({e1})")

    # Strategy 2: Explicit psycopg2 driver
    if "psycopg2" not in db_url and db_url.startswith("postgresql://"):
        try:
            alt_url = db_url.replace("postgresql://", "postgresql+psycopg2://", 1)
            return create_engine(
                alt_url,
                pool_size=settings.DATABASE_POOL_SIZE,
                max_overflow=settings.DATABASE_MAX_OVERFLOW,
                pool_pre_ping=True
            )
        except Exception as e2:
            errors.append(f"psycopg2 ({e2})")

    # Strategy 3: Explicit psycopg (psycopg3) driver
    if "+psycopg" not in db_url and db_url.startswith("postgresql://"):
        try:
            alt_url = db_url.replace("postgresql://", "postgresql+psycopg://", 1)
            return create_engine(
                alt_url,
                pool_size=settings.DATABASE_POOL_SIZE,
                max_overflow=settings.DATABASE_MAX_OVERFLOW,
                pool_pre_ping=True
            )
        except Exception as e3:
            errors.append(f"psycopg3 ({e3})")

    logger.warning(f"Could not initialize SQLAlchemy engine with {db_url}: {'; '.join(errors)}")
    return None


engine = _create_robust_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine) if engine else None


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
