"""Spatial classification engine for Euskadi stops and routes using PostGIS or Shapely."""

from typing import Dict, List, Optional, Tuple
from shapely.geometry import Point, Polygon
from sqlalchemy import text

from src.db.connection import get_db_session
from src.utils.logging import logger


class ProvincialClassifier:
    """Classifies transit stops and routes into Bizkaia, Gipuzkoa, and Araba / Álava."""

    def __init__(self, in_memory_polygons: Optional[Dict[str, Polygon]] = None):
        # Optional local cache of territorial polygons: {"48": poly, "20": poly, "01": poly}
        self.polygons = in_memory_polygons or {}

    def classify_point_in_memory(self, longitude: float, latitude: float) -> Tuple[Optional[str], float]:
        """In-memory point-in-polygon containment check using Shapely."""
        pt = Point(longitude, latitude)
        for prov_code, poly in self.polygons.items():
            if poly.contains(pt):
                return prov_code, 1.0

        # Boundary buffer check (within 500m / ~0.005 degrees)
        for prov_code, poly in self.polygons.items():
            if poly.buffer(0.005).contains(pt):
                return prov_code, 0.8

        return None, 0.0

    def classify_stops_in_database(self, feed_version_id: str) -> Dict[str, int]:
        """Runs PostGIS ST_Contains spatial classification across all stops of a feed version."""
        logger.info(f"Executing PostGIS provincial classification for feed version {feed_version_id}...")
        with get_db_session() as session:
            # 1. Match stops with provincial boundaries
            query = text("""
                INSERT INTO public.stop_provinces (
                    stop_id, province_code, classification_method, confidence, created_at
                )
                SELECT
                    s.id AS stop_id,
                    b.province_code AS province_code,
                    'spatial_polygon_containment' AS classification_method,
                    1.0 AS confidence,
                    now()
                FROM public.gtfs_stops s
                JOIN public.administrative_boundaries b
                  ON b.entity_type = 'province'
                 AND ST_Contains(b.geom, s.geom)
                WHERE s.feed_version_id = :feed_version_id
                ON CONFLICT (stop_id, province_code) DO NOTHING;
            """)
            result = session.execute(query, {"feed_version_id": feed_version_id})
            classified_stops = result.rowcount

            # 2. Derive Route Provinces from Stop Provinces
            route_query = text("""
                INSERT INTO public.route_provinces (route_id, province_code)
                SELECT DISTINCT
                    r.id AS route_id,
                    sp.province_code
                FROM public.gtfs_routes r
                JOIN public.gtfs_trips t ON t.route_id = r.id
                JOIN public.gtfs_stop_times st ON st.trip_id = t.id
                JOIN public.stop_provinces sp ON sp.stop_id = st.stop_id
                WHERE r.feed_version_id = :feed_version_id
                ON CONFLICT (route_id, province_code) DO NOTHING;
            """)
            route_res = session.execute(route_query, {"feed_version_id": feed_version_id})
            classified_routes = route_res.rowcount

            # 3. Check for unclassified stops (e.g., border towns or maritime)
            unclass_query = text("""
                SELECT count(*) FROM public.gtfs_stops s
                WHERE s.feed_version_id = :feed_version_id
                  AND NOT EXISTS (
                      SELECT 1 FROM public.stop_provinces sp WHERE sp.stop_id = s.id
                  );
            """)
            unclassified_count = session.execute(unclass_query, {"feed_version_id": feed_version_id}).scalar() or 0

            logger.info(
                f"Spatial classification complete: {classified_stops} stop-province links, "
                f"{classified_routes} route-province links, {unclassified_count} unclassified stops."
            )

            return {
                "classified_stops": classified_stops,
                "classified_routes": classified_routes,
                "unclassified_stops": unclassified_count
            }
