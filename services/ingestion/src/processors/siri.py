"""SIRI XML processor using defusedxml for security and robust namespace handling."""

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import defusedxml.ElementTree as ET
from sqlalchemy import text

from src.db.connection import get_db_session
from src.processors.base import BaseProcessor, ValidationError, ValidationReport
from src.utils.logging import logger

SIRI_NS = {"siri": "http://www.siri.org.uk/siri"}


def find_child(el, tag_with_ns: str, fallback_tag: Optional[str] = None, ns: Optional[Dict[str, str]] = None):
    """Finds an XML child element safely without bool(element) evaluation."""
    target = el.find(tag_with_ns, ns) if ns else el.find(tag_with_ns)
    if target is None and fallback_tag:
        target = el.find(fallback_tag)
    return target


class SiriProcessor(BaseProcessor):
    """Parses SIRI XML feeds (VehicleMonitoring, SituationExchange, EstimatedTimetable)."""

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="SIRI")
        operator_id = context.get("operator_id") or str(uuid.uuid4())

        try:
            tree = ET.parse(file_path)
            root = tree.getroot()

            # Handle namespaced and non-namespaced queries
            vehicle_activities = root.findall(".//siri:VehicleActivity", SIRI_NS)
            if not vehicle_activities:
                vehicle_activities = root.findall(".//VehicleActivity")

            situations = root.findall(".//siri:PtSituationElement", SIRI_NS)
            if not situations:
                situations = root.findall(".//PtSituationElement")

            logger.info(
                f"SIRI parsed: {len(vehicle_activities)} vehicle activities, {len(situations)} situation elements"
            )

            parsed_vehicles: List[Dict[str, Any]] = []
            for va in vehicle_activities:
                report.total_records += 1
                try:
                    v_ref_el = find_child(va, ".//siri:VehicleRef", ".//VehicleRef", SIRI_NS)
                    v_ref = v_ref_el.text.strip() if v_ref_el is not None and v_ref_el.text else "unknown"

                    line_el = find_child(va, ".//siri:LineRef", ".//LineRef", SIRI_NS)
                    line_ref = line_el.text.strip() if line_el is not None and line_el.text else None

                    dir_el = find_child(va, ".//siri:DirectionRef", ".//DirectionRef", SIRI_NS)
                    dir_ref = dir_el.text.strip() if dir_el is not None and dir_el.text else None

                    lon_el = find_child(va, ".//siri:Longitude", ".//Longitude", SIRI_NS)
                    lat_el = find_child(va, ".//siri:Latitude", ".//Latitude", SIRI_NS)

                    rec_time_el = find_child(va, ".//siri:RecordedAtTime", ".//RecordedAtTime", SIRI_NS)
                    rec_time = None
                    if rec_time_el is not None and rec_time_el.text:
                        rec_time = datetime.fromisoformat(rec_time_el.text.replace("Z", "+00:00"))
                    else:
                        rec_time = datetime.now(timezone.utc)

                    if lon_el is not None and lat_el is not None and lon_el.text and lat_el.text:
                        lat = float(lat_el.text)
                        lon = float(lon_el.text)
                        if 41.0 <= lat <= 44.5 and -4.5 <= lon <= -1.0:
                            parsed_vehicles.append({
                                "id": str(uuid.uuid4()),
                                "operator_id": operator_id,
                                "vehicle_ref": v_ref,
                                "line_ref": line_ref,
                                "direction_ref": dir_ref,
                                "latitude": lat,
                                "longitude": lon,
                                "recorded_at": rec_time
                            })
                            report.valid_records += 1
                        else:
                            report.rejected_records += 1
                    else:
                        report.rejected_records += 1
                except Exception as ex:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("siri_vehicle", "parse", str(ex)))

            parsed_situations: List[Dict[str, Any]] = []
            for sit in situations:
                report.total_records += 1
                try:
                    num_el = find_child(sit, ".//siri:SituationNumber", ".//SituationNumber", SIRI_NS)
                    sit_num = num_el.text.strip() if num_el is not None and num_el.text else str(uuid.uuid4())

                    sum_el = find_child(sit, ".//siri:Summary", ".//Summary", SIRI_NS)
                    summary = sum_el.text.strip() if sum_el is not None and sum_el.text else "Incidencia de servicio"

                    desc_el = find_child(sit, ".//siri:Description", ".//Description", SIRI_NS)
                    description = desc_el.text.strip() if desc_el is not None and desc_el.text else None

                    parsed_situations.append({
                        "id": str(uuid.uuid4()),
                        "operator_id": operator_id,
                        "situation_number": sit_num,
                        "summary": summary,
                        "description": description
                    })
                    report.valid_records += 1
                except Exception as ex:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("siri_situation", "parse", str(ex)))

            report.metrics["siri_vehicles"] = len(parsed_vehicles)
            report.metrics["siri_situations"] = len(parsed_situations)

            if context.get("persist_to_db", False) and (parsed_vehicles or parsed_situations):
                self._persist_siri(operator_id, parsed_vehicles, parsed_situations)

            report.mark_completed()
            return report

        except Exception as e:
            report.rejected_records += 1
            report.errors.append(ValidationError("siri_xml", file_path, f"SIRI parsing failure: {e}"))
            report.mark_completed("failed")
            logger.error(f"SIRI parse error: {e}")
            return report

    def _persist_siri(
        self,
        operator_id: str,
        vehicles: List[Dict[str, Any]],
        situations: List[Dict[str, Any]]
    ):
        """Persists SIRI observations into database."""
        with get_db_session() as session:
            if vehicles:
                ins_veh_sql = text("""
                    INSERT INTO public.siri_vehicle_observations (
                        id, operator_id, vehicle_ref, line_ref, direction_ref,
                        latitude, longitude, geom, recorded_at
                    ) VALUES (
                        :id, :operator_id, :vehicle_ref, :line_ref, :direction_ref,
                        :latitude, :longitude,
                        ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326),
                        :recorded_at
                    );
                """)
                session.execute(ins_veh_sql, vehicles)

            if situations:
                ins_sit_sql = text("""
                    INSERT INTO public.siri_situation_exchanges (
                        id, operator_id, situation_number, summary, description
                    ) VALUES (
                        :id, :operator_id, :situation_number, :summary, :description
                    );
                """)
                session.execute(ins_sit_sql, situations)
