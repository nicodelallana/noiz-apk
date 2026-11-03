"""Pydantic data models for Moveuskadi catalog entities."""

from datetime import datetime, timezone
from typing import Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class ResourceItem(BaseModel):
    """Individual data resource published in data-index.json."""
    model_config = ConfigDict(populate_by_name=True)

    format: str = Field(..., description="Resource format: GTFS, GTFS-RT, SIRI, NETEX, etc.")
    url: str = Field(..., description="Direct downloadable resource URL")
    name: str = Field(..., description="Published file name")
    last_update: Optional[str] = Field(None, alias="last-update", description="Catalogue timestamp")


class OperatorCatalog(BaseModel):
    """Operator details discovered in the Moveuskadi index."""
    original_name: str
    normalized_name: str
    slug: str
    resources: List[ResourceItem] = Field(default_factory=list)
    available_formats: List[str] = Field(default_factory=list)
    last_seen_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class CatalogueDiff(BaseModel):
    """Differences detected between successive catalogue polls."""
    new_operators: List[str] = Field(default_factory=list)
    deprecated_operators: List[str] = Field(default_factory=list)
    new_resources: List[ResourceItem] = Field(default_factory=list)
    updated_resources: List[ResourceItem] = Field(default_factory=list)
    removed_resources: List[ResourceItem] = Field(default_factory=list)
    has_changes: bool = False


class CatalogueSnapshot(BaseModel):
    """Complete snapshot of the Moveuskadi JSON index."""
    catalogue_url: str
    catalogue_last_update: Optional[str] = None
    retrieved_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    checksum: str
    total_operators: int
    total_resources: int
    operators: Dict[str, List[ResourceItem]]
