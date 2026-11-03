"""Shapefile processor and GeoEuskadi administrative boundary importer."""

import io
import os
import tempfile
import uuid
import zipfile
from typing import Any, Dict, List, Optional, Tuple
from pyproj import Transformer
import shapefile
from shapely.geometry import MultiPolygon, Polygon, mapping, shape
import shapely
from sqlalchemy import text

from src.db.connection import get_db_session
from src.processors.base import BaseProcessor, ValidationError, ValidationReport
from src.utils.logging import logger


class ShapefileProcessor(BaseProcessor):
    """Processes Shapefile datasets and converts ETRS89 UTM 30N coordinates to WGS84."""

    def __init__(self, source_crs: str = "EPSG:25830", target_crs: str = "EPSG:4326"):
        self.source_crs = source_crs
        self.target_crs = target_crs
        self.transformer = Transformer.from_crs(source_crs, target_crs, always_xy=True)

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="SHP")

        if not os.path.exists(file_path):
            report.rejected_records += 1
            report.errors.append(ValidationError("shp_file", file_path, "File not found"))
            report.mark_completed("failed")
            return report

        try:
            records = self.read_shapefile(file_path)
            report.total_records = len(records)
            report.valid_records = len(records)
            report.metrics["feature_count"] = len(records)
            report.mark_completed("passed")
            return report
        except Exception as e:
            report.rejected_records += 1
            report.errors.append(ValidationError("shp_parse", file_path, str(e)))
            report.mark_completed("failed")
            return report

    def read_shapefile(self, file_path: str) -> List[Tuple[Dict[str, Any], Any]]:
        """Reads shapefile components directly from a .zip or .shp file."""
        features = []

        if file_path.endswith(".zip"):
            with zipfile.ZipFile(file_path, "r") as z:
                # Find shp, shx, dbf
                shp_name = next((f for f in z.namelist() if f.endswith(".shp")), None)
                shx_name = next((f for f in z.namelist() if f.endswith(".shx")), None)
                dbf_name = next((f for f in z.namelist() if f.endswith(".dbf")), None)

                if not shp_name or not dbf_name:
                    raise ValueError("ZIP does not contain required .shp and .dbf files")

                sf = shapefile.Reader(
                    shp=io.BytesIO(z.read(shp_name)),
                    shx=io.BytesIO(z.read(shx_name)) if shx_name else None,
                    dbf=io.BytesIO(z.read(dbf_name)),
                    encoding="latin1"
                )
                features = self._parse_reader(sf)
        else:
            sf = shapefile.Reader(file_path, encoding="latin1")
            features = self._parse_reader(sf)

        return features

    def _parse_reader(self, sf: shapefile.Reader) -> List[Tuple[Dict[str, Any], Any]]:
        parsed = []
        for shape_rec in sf.shapeRecords():
            props = shape_rec.record.as_dict()
            geom_raw = shape(shape_rec.shape.__geo_interface__)
            # Reproject from ETRS89 to WGS84
            geom_wgs84 = shapely.transform(geom_raw, self.transformer.transform, interleaved=False)
            parsed.append((props, geom_wgs84))
        return parsed

    def import_euskadi_territorial_boundaries(self, zip_path: str) -> int:
        """Imports official GeoEuskadi TERRITORIOS_5000_ETRS89 into PostGIS."""
        features = self.read_shapefile(zip_path)
        logger.info(f"Importing {len(features)} territorial boundaries from GeoEuskadi...")

        # Map INE province code: 48 -> Bizkaia, 20 -> Gipuzkoa, 01 -> Araba
        code_map = {
            "01": "01",
            "20": "20",
            "48": "48"
        }

        with get_db_session() as session:
            count = 0
            for props, geom_wgs84 in features:
                prov_code = str(props.get("PRO_PROV", "")).strip().zfill(2)
                name = str(props.get("TERRITORIO", "")).strip()

                if prov_code in code_map:
                    # Convert to MultiPolygon WKT if Polygon
                    if geom_wgs84.geom_type == "Polygon":
                        geom_wgs84 = MultiPolygon([geom_wgs84])

                    wkt_geom = geom_wgs84.wkt

                    # Upsert into administrative_boundaries
                    upsert_sql = text("""
                        INSERT INTO public.administrative_boundaries (
                            id, entity_type, code, name, province_code, geom, source, updated_at
                        ) VALUES (
                            gen_random_uuid(), 'province', :code, :name, :code,
                            ST_Multi(ST_GeomFromText(:wkt, 4326)), 'GeoEuskadi', now()
                        )
                        ON CONFLICT DO NOTHING;
                    """)
                    session.execute(upsert_sql, {
                        "code": prov_code,
                        "name": name,
                        "wkt": wkt_geom
                    })
                    count += 1

            logger.info(f"Successfully loaded {count} territorial boundaries into PostGIS.")
            return count
