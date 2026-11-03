"""Unit and integration tests for Shapefile processing and spatial provincial classification."""

import os
import tempfile
from shapely.geometry import Point
from src.downloader.manager import DownloadManager
from src.processors.shp import ShapefileProcessor
from src.spatial.classifier import ProvincialClassifier


def test_download_and_parse_euskadi_territorial_boundaries():
    """Downloads official GeoEuskadi TERRITORIOS_5000_ETRS89.zip and validates 3 territories."""
    with tempfile.TemporaryDirectory() as tmpdir:
        dm = DownloadManager(base_dir=tmpdir)
        url = "https://www.geo.euskadi.eus/cartografia/DatosDescarga/Limites/TERRITORIOS_5000_ETRS89.zip"
        dl = dm.download_resource(url, "territorios.zip", "SHP")
        assert dl.success is True

        shp_proc = ShapefileProcessor()
        features = shp_proc.read_shapefile(dl.file_path)
        assert len(features) == 3

        territory_polys = {}
        for props, geom_wgs84 in features:
            prov_code = str(props.get("PRO_PROV", "")).strip().zfill(2)
            name = str(props.get("TERRITORIO", "")).strip()
            territory_polys[prov_code] = geom_wgs84
            # Verify coordinates are in valid lat/long range
            bounds = geom_wgs84.bounds
            assert -3.6 <= bounds[0] <= -1.5  # min_lon
            assert 42.0 <= bounds[1] <= 44.0  # min_lat

        # Test Point-in-Polygon containment:
        classifier = ProvincialClassifier(in_memory_polygons=territory_polys)

        # 1. Moyua (Bilbao, Bizkaia)
        code_bizkaia, conf_b = classifier.classify_point_in_memory(-2.9348, 43.2630)
        assert code_bizkaia == "48"
        assert conf_b == 1.0

        # 2. Boulevard (Donostia-San Sebastián, Gipuzkoa)
        code_gipuzkoa, conf_g = classifier.classify_point_in_memory(-1.9812, 43.3216)
        assert code_gipuzkoa == "20"
        assert conf_g == 1.0

        # 3. Plaza de la Paz (Vitoria-Gasteiz, Araba / Álava)
        code_araba, conf_a = classifier.classify_point_in_memory(-2.6710, 42.8467)
        assert code_araba == "01"
        assert conf_a == 1.0

        # 4. Point outside Euskadi (Santander, Cantabria)
        code_outside, conf_out = classifier.classify_point_in_memory(-3.8050, 43.4623)
        assert code_outside is None
        assert conf_out == 0.0
