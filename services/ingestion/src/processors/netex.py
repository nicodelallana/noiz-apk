"""NeTEx XML / ZIP archive processor."""

import os
import tempfile
import uuid
from typing import Any, Dict, List, Optional
import defusedxml.ElementTree as ET
from sqlalchemy import text

from src.db.connection import get_db_session
from src.processors.base import BaseProcessor, ValidationError, ValidationReport
from src.processors.gtfs_static import safe_extract_zip
from src.utils.logging import logger

NETEX_NS = {"netex": "http://www.netex.org.uk/netex"}


def find_child(el, tag_with_ns: str, fallback_tag: Optional[str] = None, ns: Optional[Dict[str, str]] = None):
    """Finds an XML child element safely without bool(element) evaluation."""
    target = el.find(tag_with_ns, ns) if ns else el.find(tag_with_ns)
    if target is None and fallback_tag:
        target = el.find(fallback_tag)
    return target


class NetexProcessor(BaseProcessor):
    """Processes NeTEx zip archives containing European standard public transit XMLs."""

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="NETEX")
        operator_id = context.get("operator_id") or str(uuid.uuid4())
        feed_version_id = context.get("feed_version_id")

        if not os.path.exists(file_path):
            report.rejected_records += 1
            report.errors.append(ValidationError("netex_file", file_path, "File not found"))
            report.mark_completed("failed")
            return report

        temp_extract = tempfile.mkdtemp(prefix="netex_extract_")
        try:
            safe_extract_zip(file_path, temp_extract)
            xml_files = [f for f in os.listdir(temp_extract) if f.endswith(".xml")]
            logger.info(f"NeTEx XML files found: {xml_files}")

            stops_count = 0
            lines_count = 0
            routes_count = 0

            for xf in xml_files:
                xf_path = os.path.join(temp_extract, xf)
                try:
                    tree = ET.parse(xf_path)
                    root = tree.getroot()

                    # Find ScheduledStopPoints
                    stop_points = root.findall(".//netex:ScheduledStopPoint", NETEX_NS)
                    if not stop_points:
                        stop_points = root.findall(".//ScheduledStopPoint")

                    for sp in stop_points:
                        report.total_records += 1
                        sp_name = find_child(sp, ".//netex:Name", ".//Name", NETEX_NS)
                        if sp_name is not None and sp_name.text:
                            stops_count += 1
                            report.valid_records += 1
                        else:
                            report.rejected_records += 1

                    # Find Lines
                    lines = root.findall(".//netex:Line", NETEX_NS)
                    if not lines:
                        lines = root.findall(".//Line")

                    for ln in lines:
                        report.total_records += 1
                        l_name = find_child(ln, ".//netex:Name", ".//Name", NETEX_NS)
                        if l_name is not None and l_name.text:
                            lines_count += 1
                            report.valid_records += 1
                        else:
                            report.rejected_records += 1

                    # Find Routes
                    routes = root.findall(".//netex:Route", NETEX_NS)
                    if not routes:
                        routes = root.findall(".//Route")

                    for rt in routes:
                        report.total_records += 1
                        routes_count += 1
                        report.valid_records += 1

                except Exception as ex:
                    report.rejected_records += 1
                    report.errors.append(ValidationError("netex_xml", xf, str(ex)))

            report.metrics["netex_stops"] = stops_count
            report.metrics["netex_lines"] = lines_count
            report.metrics["netex_routes"] = routes_count

            if context.get("persist_to_db", False):
                import json
                with get_db_session() as session:
                    session.execute(
                        text("""
                            INSERT INTO public.netex_resources (
                                id, operator_id, feed_version_id, resource_name, elements_parsed
                            ) VALUES (
                                :id, :op_id, :f_ver, :res_name, :elements::jsonb
                            );
                        """),
                        {
                            "id": str(uuid.uuid4()),
                            "op_id": operator_id,
                            "f_ver": feed_version_id,
                            "res_name": os.path.basename(file_path),
                            "elements": json.dumps(report.metrics)
                        }
                    )

            report.mark_completed()
            return report

        finally:
            if os.path.exists(temp_extract):
                import shutil
                shutil.rmtree(temp_extract, ignore_errors=True)
