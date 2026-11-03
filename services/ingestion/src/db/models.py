"""SQLAlchemy ORM models mirroring the Supabase relational schema."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    ARRAY, Boolean, Column, DateTime, Float, ForeignKey, Integer, SmallInteger,
    String, Text, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from src.db.connection import Base


class Province(Base):
    __tablename__ = "provinces"
    code = Column(String, primary_key=True)
    name_es = Column(String, nullable=False)
    name_eu = Column(String, nullable=False)
    slug = Column(String, nullable=False, unique=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class TransportMode(Base):
    __tablename__ = "transport_modes"
    id = Column(String, primary_key=True)
    name_es = Column(String, nullable=False)
    name_eu = Column(String, nullable=False)
    gtfs_route_type = Column(Integer, nullable=False)
    icon_name = Column(String, nullable=False, default="directions_bus")
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class TransportOperator(Base):
    __tablename__ = "transport_operators"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    original_name = Column(String, nullable=False, unique=True)
    normalized_name = Column(String, nullable=False)
    slug = Column(String, nullable=False, unique=True)
    is_active = Column(Boolean, nullable=False, default=True)
    available_formats = Column(ARRAY(String), nullable=False, default=[])
    primary_color = Column(String, nullable=False, default="#025DA9")
    website_url = Column(String)
    source_metadata = Column(JSONB, nullable=False, default={})
    last_catalogue_seen_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    last_static_import_at = Column(DateTime(timezone=True))
    last_realtime_sync_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class OperatorProvince(Base):
    __tablename__ = "operator_provinces"
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), primary_key=True)
    province_code = Column(String, ForeignKey("provinces.code", ondelete="CASCADE"), primary_key=True)
    is_primary = Column(Boolean, nullable=False, default=False)
    confidence = Column(Float, nullable=False, default=1.0)
    evidence_source = Column(String, nullable=False, default="spatial_stops_distribution")


class CatalogueSnapshotModel(Base):
    __tablename__ = "catalogue_snapshots"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    catalogue_url = Column(String, nullable=False)
    retrieved_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    catalogue_last_update = Column(String)
    total_operators = Column(Integer, nullable=False, default=0)
    total_resources = Column(Integer, nullable=False, default=0)
    checksum = Column(String, nullable=False)
    raw_payload = Column(JSONB, nullable=False)
    status = Column(String, nullable=False, default="processed")
    error_message = Column(Text)


class CatalogueResourceModel(Base):
    __tablename__ = "catalogue_resources"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    format = Column(String, nullable=False)
    name = Column(String, nullable=False)
    url = Column(String, nullable=False)
    catalogue_last_update = Column(String)
    last_discovered_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    last_downloaded_at = Column(DateTime(timezone=True))
    last_checksum = Column(String)
    file_size_bytes = Column(Integer)
    is_active = Column(Boolean, nullable=False, default=True)

    __table_args__ = (UniqueConstraint("operator_id", "url", name="uq_operator_resource_url"),)


class FeedVersion(Base):
    __tablename__ = "feed_versions"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    format = Column(String, nullable=False)
    resource_url = Column(String, nullable=False)
    catalogue_timestamp = Column(String)
    download_timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    checksum = Column(String, nullable=False)
    file_size_bytes = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="importing")
    records_processed = Column(JSONB, nullable=False, default={})
    validation_status = Column(String, nullable=False, default="pending")
    validation_report = Column(JSONB, nullable=False, default={})
    activated_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class IngestionJob(Base):
    __tablename__ = "ingestion_jobs"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    job_type = Column(String, nullable=False)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"))
    feed_version_id = Column(UUID(as_uuid=True), ForeignKey("feed_versions.id", ondelete="SET NULL"))
    resource_url = Column(String)
    status = Column(String, nullable=False, default="running")
    started_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    completed_at = Column(DateTime(timezone=True))
    metrics = Column(JSONB, nullable=False, default={})
    error_message = Column(Text)


class IngestionError(Base):
    __tablename__ = "ingestion_errors"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    job_id = Column(UUID(as_uuid=True), ForeignKey("ingestion_jobs.id", ondelete="CASCADE"))
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="SET NULL"))
    error_type = Column(String, nullable=False)
    error_message = Column(Text, nullable=False)
    context_data = Column(JSONB, nullable=False, default={})
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class GTFSStop(Base):
    __tablename__ = "gtfs_stops"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    feed_version_id = Column(UUID(as_uuid=True), ForeignKey("feed_versions.id", ondelete="CASCADE"), nullable=False)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    external_stop_id = Column(String, nullable=False)
    stop_code = Column(String)
    stop_name = Column(String, nullable=False)
    stop_desc = Column(String)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    zone_id = Column(String)
    stop_url = Column(String)
    location_type = Column(Integer, nullable=False, default=0)
    wheelchair_boarding = Column(Integer, default=0)
    platform_code = Column(String)

    __table_args__ = (UniqueConstraint("feed_version_id", "external_stop_id", name="uq_feed_ext_stop"),)


class StopProvince(Base):
    __tablename__ = "stop_provinces"
    stop_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_stops.id", ondelete="CASCADE"), primary_key=True)
    province_code = Column(String, ForeignKey("provinces.code", ondelete="CASCADE"), primary_key=True)
    classification_method = Column(String, nullable=False, default="spatial_polygon_containment")
    confidence = Column(Float, nullable=False, default=1.0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class GTFSRoute(Base):
    __tablename__ = "gtfs_routes"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    feed_version_id = Column(UUID(as_uuid=True), ForeignKey("feed_versions.id", ondelete="CASCADE"), nullable=False)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    agency_id = Column(String)
    external_route_id = Column(String, nullable=False)
    route_short_name = Column(String, nullable=False)
    route_long_name = Column(String, nullable=False)
    route_desc = Column(String)
    route_type = Column(Integer, nullable=False)
    route_url = Column(String)
    route_color = Column(String, nullable=False, default="025DA9")
    route_text_color = Column(String, nullable=False, default="FFFFFF")

    __table_args__ = (UniqueConstraint("feed_version_id", "external_route_id", name="uq_feed_ext_route"),)


class RouteProvince(Base):
    __tablename__ = "route_provinces"
    route_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_routes.id", ondelete="CASCADE"), primary_key=True)
    province_code = Column(String, ForeignKey("provinces.code", ondelete="CASCADE"), primary_key=True)


class GTFSTrip(Base):
    __tablename__ = "gtfs_trips"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    feed_version_id = Column(UUID(as_uuid=True), ForeignKey("feed_versions.id", ondelete="CASCADE"), nullable=False)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    route_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_routes.id", ondelete="CASCADE"), nullable=False)
    external_trip_id = Column(String, nullable=False)
    service_id = Column(String, nullable=False)
    trip_headsign = Column(String)
    trip_short_name = Column(String)
    direction_id = Column(SmallInteger)
    block_id = Column(String)
    shape_id = Column(String)
    wheelchair_accessible = Column(SmallInteger, default=0)
    bikes_allowed = Column(SmallInteger, default=0)

    __table_args__ = (UniqueConstraint("feed_version_id", "external_trip_id", name="uq_feed_ext_trip"),)


class GTFSStopTime(Base):
    __tablename__ = "gtfs_stop_times"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    feed_version_id = Column(UUID(as_uuid=True), ForeignKey("feed_versions.id", ondelete="CASCADE"), nullable=False)
    trip_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_trips.id", ondelete="CASCADE"), nullable=False)
    stop_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_stops.id", ondelete="CASCADE"), nullable=False)
    external_trip_id = Column(String, nullable=False)
    external_stop_id = Column(String, nullable=False)
    arrival_time = Column(String, nullable=False)
    departure_time = Column(String, nullable=False)
    stop_sequence = Column(Integer, nullable=False)
    stop_headsign = Column(String)
    pickup_type = Column(SmallInteger, default=0)
    drop_off_type = Column(SmallInteger, default=0)
    shape_dist_traveled = Column(Float)
    timepoint = Column(SmallInteger, default=1)

    __table_args__ = (UniqueConstraint("feed_version_id", "external_trip_id", "stop_sequence", name="uq_feed_trip_seq"),)


class VehiclePositionModel(Base):
    __tablename__ = "vehicle_positions"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    operator_id = Column(UUID(as_uuid=True), ForeignKey("transport_operators.id", ondelete="CASCADE"), nullable=False)
    snapshot_id = Column(UUID(as_uuid=True))
    vehicle_id = Column(String, nullable=False)
    vehicle_label = Column(String)
    license_plate = Column(String)
    external_trip_id = Column(String)
    external_route_id = Column(String)
    trip_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_trips.id", ondelete="SET NULL"))
    route_id = Column(UUID(as_uuid=True), ForeignKey("gtfs_routes.id", ondelete="SET NULL"))
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    bearing = Column(Float)
    odometer = Column(Float)
    speed = Column(Float)
    current_stop_sequence = Column(Integer)
    current_status = Column(String)
    timestamp = Column(DateTime(timezone=True), nullable=False)
    congestion_level = Column(String)
    occupancy_status = Column(String)
    is_latest = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
