"""Complete GTFS Static feed processor and referential validator."""

import csv
import io
import os
import tempfile
import uuid
import zipfile
from typing import Any, Dict, List, Optional, Set
from sqlalchemy import text

from src.db.connection import get_db_session
from src.processors.base import BaseProcessor, ValidationError, ValidationReport
from src.utils.logging import logger


def safe_extract_zip(zip_path: str, extract_dir: str):
    """Safely extracts zip archive preventing path traversal (Zip Slip)."""
    with zipfile.ZipFile(zip_path, "r") as z:
        for member in z.infolist():
            target_path = os.path.realpath(os.path.join(extract_dir, member.filename))
            if not target_path.startswith(os.path.realpath(extract_dir) + os.sep):
                raise ValueError(f"Malicious zip entry detected: {member.filename}")
        z.extractall(extract_dir)


def parse_csv_file(file_path: str) -> List[Dict[str, str]]:
    """Reads a GTFS txt file stripping BOM and whitespace."""
    if not os.path.exists(file_path):
        return []
    rows = []
    with open(file_path, "r", encoding="utf-8-sig", errors="replace") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            return []
        # Clean field names
        cleaned_fields = [fn.strip() for fn in reader.fieldnames if fn]
        for line in reader:
            row = {k.strip(): (v.strip() if v else "") for k, v in line.items() if k}
            rows.append(row)
    return rows


class GTFSStaticProcessor(BaseProcessor):
    """Parses and validates static GTFS feeds, enforcing namespace isolation."""

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="GTFS")
        feed_version_id = context.get("feed_version_id") or str(uuid.uuid4())
        operator_id = context.get("operator_id") or str(uuid.uuid4())

        if not os.path.exists(file_path):
            report.rejected_records += 1
            report.errors.append(ValidationError("file", file_path, "File does not exist"))
            report.mark_completed("failed")
            return report

        temp_extract_dir = tempfile.mkdtemp(prefix="gtfs_extract_")
        try:
            safe_extract_zip(file_path, temp_extract_dir)
            extracted_files = set(os.listdir(temp_extract_dir))
            logger.info(f"GTFS extracted files: {extracted_files}")

            # Check required files
            required_files = {"stops.txt", "routes.txt", "trips.txt", "stop_times.txt"}
            missing_required = required_files - extracted_files
            if missing_required:
                report.rejected_records += 1
                report.errors.append(
                    ValidationError("schema", "gtfs_archive", f"Missing required GTFS files: {missing_required}")
                )
                report.mark_completed("failed")
                return report

            # 1. Parse Agencies
            agency_rows = parse_csv_file(os.path.join(temp_extract_dir, "agency.txt"))
            agencies_by_id = {}
            for a in agency_rows:
                a_id = a.get("agency_id") or "default_agency"
                agencies_by_id[a_id] = a
            report.metrics["agencies_count"] = len(agency_rows)

            # 2. Parse Stops
            stop_rows = parse_csv_file(os.path.join(temp_extract_dir, "stops.txt"))
            valid_stops = {}
            for s in stop_rows:
                report.total_records += 1
                ext_id = s.get("stop_id")
                name = s.get("stop_name")
                lat_str = s.get("stop_lat")
                lon_str = s.get("stop_lon")

                if not ext_id or not name or not lat_str or not lon_str:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("stop", str(ext_id), "Missing mandatory fields in stop"))
                    continue

                try:
                    lat = float(lat_str)
                    lon = float(lon_str)
                    # Coordinates bounding check (wider Basque Country / Northern Spain)
                    if not (41.0 <= lat <= 44.5 and -4.5 <= lon <= -1.0):
                        report.rejected_records += 1
                        report.errors.append(
                            ValidationError("stop", ext_id, f"Stop coordinates out of bounds: ({lat}, {lon})")
                        )
                        continue

                    valid_stops[ext_id] = {
                        "id": str(uuid.uuid4()),
                        "feed_version_id": feed_version_id,
                        "operator_id": operator_id,
                        "external_stop_id": ext_id,
                        "stop_code": s.get("stop_code") or None,
                        "stop_name": name,
                        "stop_desc": s.get("stop_desc") or None,
                        "latitude": lat,
                        "longitude": lon,
                        "zone_id": s.get("zone_id") or None,
                        "location_type": int(s.get("location_type") or 0)
                    }
                    report.valid_records += 1
                except ValueError:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("stop", ext_id, "Invalid numeric coordinates"))

            report.metrics["stops_count"] = len(valid_stops)

            # 3. Parse Routes
            route_rows = parse_csv_file(os.path.join(temp_extract_dir, "routes.txt"))
            valid_routes = {}
            for r in route_rows:
                report.total_records += 1
                r_ext_id = r.get("route_id")
                short_name = r.get("route_short_name") or ""
                long_name = r.get("route_long_name") or ""
                type_str = r.get("route_type")

                if not r_ext_id or (not short_name and not long_name):
                    report.rejected_records += 1
                    report.errors.append(ValidationError("route", str(r_ext_id), "Route missing ID or names"))
                    continue

                try:
                    r_type = int(type_str) if type_str is not None else 3
                except ValueError:
                    r_type = 3

                valid_routes[r_ext_id] = {
                    "id": str(uuid.uuid4()),
                    "feed_version_id": feed_version_id,
                    "operator_id": operator_id,
                    "agency_id": r.get("agency_id"),
                    "external_route_id": r_ext_id,
                    "route_short_name": short_name or long_name[:10],
                    "route_long_name": long_name or short_name,
                    "route_desc": r.get("route_desc"),
                    "route_type": r_type,
                    "route_color": r.get("route_color") or "025DA9",
                    "route_text_color": r.get("route_text_color") or "FFFFFF"
                }
                report.valid_records += 1

            report.metrics["routes_count"] = len(valid_routes)

            # 4. Parse Trips
            trip_rows = parse_csv_file(os.path.join(temp_extract_dir, "trips.txt"))
            valid_trips = {}
            for t in trip_rows:
                report.total_records += 1
                t_ext_id = t.get("trip_id")
                r_ext_id = t.get("route_id")
                s_id = t.get("service_id")

                if not t_ext_id or not r_ext_id or not s_id:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("trip", str(t_ext_id), "Trip missing ID, route, or service"))
                    continue

                if r_ext_id not in valid_routes:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("trip", t_ext_id, f"Trip references unknown route {r_ext_id}"))
                    continue

                dir_id = None
                if t.get("direction_id") in ("0", "1"):
                    dir_id = int(t.get("direction_id"))

                valid_trips[t_ext_id] = {
                    "id": str(uuid.uuid4()),
                    "feed_version_id": feed_version_id,
                    "operator_id": operator_id,
                    "route_id": valid_routes[r_ext_id]["id"],
                    "external_trip_id": t_ext_id,
                    "service_id": s_id,
                    "trip_headsign": t.get("trip_headsign"),
                    "trip_short_name": t.get("trip_short_name"),
                    "direction_id": dir_id,
                    "block_id": t.get("block_id"),
                    "shape_id": t.get("shape_id")
                }
                report.valid_records += 1

            report.metrics["trips_count"] = len(valid_trips)

            # 5. Parse Stop Times
            st_rows = parse_csv_file(os.path.join(temp_extract_dir, "stop_times.txt"))
            valid_stop_times = []
            for st in st_rows:
                report.total_records += 1
                t_ext = st.get("trip_id")
                s_ext = st.get("stop_id")
                seq_str = st.get("stop_sequence")
                arr = st.get("arrival_time")
                dep = st.get("departure_time")

                if not t_ext or not s_ext or seq_str is None or not arr or not dep:
                    report.rejected_records += 1
                    continue

                if t_ext not in valid_trips or s_ext not in valid_stops:
                    report.rejected_records += 1
                    continue

                try:
                    seq = int(seq_str)
                    valid_stop_times.append({
                        "id": str(uuid.uuid4()),
                        "feed_version_id": feed_version_id,
                        "trip_id": valid_trips[t_ext]["id"],
                        "stop_id": valid_stops[s_ext]["id"],
                        "external_trip_id": t_ext,
                        "external_stop_id": s_ext,
                        "arrival_time": arr,
                        "departure_time": dep,
                        "stop_sequence": seq,
                        "stop_headsign": st.get("stop_headsign")
                    })
                    report.valid_records += 1
                except ValueError:
                    report.rejected_records += 1

            report.metrics["stop_times_count"] = len(valid_stop_times)

            # Check if database insertion is requested in context
            if context.get("persist_to_db", False):
                self._persist_to_database(
                    feed_version_id=feed_version_id,
                    operator_id=operator_id,
                    stops=list(valid_stops.values()),
                    routes=list(valid_routes.values()),
                    trips=list(valid_trips.values()),
                    stop_times=valid_stop_times
                )

            report.mark_completed()
            logger.info(
                f"GTFS processing finished: {report.status} - "
                f"{len(valid_stops)} stops, {len(valid_routes)} routes, "
                f"{len(valid_trips)} trips, {len(valid_stop_times)} stop_times."
            )
            return report

        finally:
            if os.path.exists(temp_extract_dir):
                import shutil
                shutil.rmtree(temp_extract_dir, ignore_errors=True)

    def _persist_to_database(
        self,
        feed_version_id: str,
        operator_id: str,
        stops: List[Dict[str, Any]],
        routes: List[Dict[str, Any]],
        trips: List[Dict[str, Any]],
        stop_times: List[Dict[str, Any]]
    ):
        """Batch persists validated entities into PostgreSQL."""
        with get_db_session() as session:
            # Insert Stops with PostGIS Point
            if stops:
                insert_stop_sql = text("""
                    INSERT INTO public.gtfs_stops (
                        id, feed_version_id, operator_id, external_stop_id,
                        stop_code, stop_name, stop_desc, latitude, longitude,
                        geom, zone_id, location_type
                    ) VALUES (
                        :id, :feed_version_id, :operator_id, :external_stop_id,
                        :stop_code, :stop_name, :stop_desc, :latitude, :longitude,
                        ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326),
                        :zone_id, :location_type
                    ) ON CONFLICT (feed_version_id, external_stop_id) DO NOTHING;
                """)
                session.execute(insert_stop_sql, stops)

            # Insert Routes
            if routes:
                insert_route_sql = text("""
                    INSERT INTO public.gtfs_routes (
                        id, feed_version_id, operator_id, agency_id, external_route_id,
                        route_short_name, route_long_name, route_desc, route_type,
                        route_color, route_text_color
                    ) VALUES (
                        :id, :feed_version_id, :operator_id, :agency_id, :external_route_id,
                        :route_short_name, :route_long_name, :route_desc, :route_type,
                        :route_color, :route_text_color
                    ) ON CONFLICT (feed_version_id, external_route_id) DO NOTHING;
                """)
                session.execute(insert_route_sql, routes)

            # Insert Trips
            if trips:
                insert_trip_sql = text("""
                    INSERT INTO public.gtfs_trips (
                        id, feed_version_id, operator_id, route_id, external_trip_id,
                        service_id, trip_headsign, trip_short_name, direction_id,
                        block_id, shape_id
                    ) VALUES (
                        :id, :feed_version_id, :operator_id, :route_id, :external_trip_id,
                        :service_id, :trip_headsign, :trip_short_name, :direction_id,
                        :block_id, :shape_id
                    ) ON CONFLICT (feed_version_id, external_trip_id) DO NOTHING;
                """)
                session.execute(insert_trip_sql, trips)

            # Insert Stop Times in chunks
            if stop_times:
                insert_st_sql = text("""
                    INSERT INTO public.gtfs_stop_times (
                        id, feed_version_id, trip_id, stop_id, external_trip_id,
                        external_stop_id, arrival_time, departure_time,
                        stop_sequence, stop_headsign
                    ) VALUES (
                        :id, :feed_version_id, :trip_id, :stop_id, :external_trip_id,
                        :external_stop_id, :arrival_time, :departure_time,
                        :stop_sequence, :stop_headsign
                    ) ON CONFLICT (feed_version_id, external_trip_id, stop_sequence) DO NOTHING;
                """)
                chunk_size = 1000
                for i in range(0, len(stop_times), chunk_size):
                    session.execute(insert_st_sql, stop_times[i:i + chunk_size])
