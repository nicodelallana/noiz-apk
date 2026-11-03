"""GTFS-Realtime Protobuf processor for Vehicle Positions, Trip Updates, and Service Alerts."""

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from google.transit import gtfs_realtime_pb2
from sqlalchemy import text

from src.db.connection import get_db_session
from src.processors.base import BaseProcessor, ValidationError, ValidationReport
from src.utils.logging import logger


class GTFSRealtimeProcessor(BaseProcessor):
    """Decodes GTFS-RT Protocol Buffers and normalizes telemetry into database."""

    def process(self, file_path: str, context: Dict[str, Any]) -> ValidationReport:
        report = ValidationReport(resource_format="GTFS-RT")
        operator_id = context.get("operator_id") or str(uuid.uuid4())

        try:
            with open(file_path, "rb") as f:
                raw_bytes = f.read()

            feed = gtfs_realtime_pb2.FeedMessage()
            feed.ParseFromString(raw_bytes)

            feed_header_ts = feed.header.timestamp
            header_dt = datetime.fromtimestamp(feed_header_ts, tz=timezone.utc) if feed_header_ts else datetime.now(timezone.utc)
            report.metrics["feed_timestamp"] = header_dt.isoformat()
            report.metrics["entity_count"] = len(feed.entity)
            logger.info(f"GTFS-RT header timestamp: {header_dt}, entity count: {len(feed.entity)}")

            vehicles: List[Dict[str, Any]] = []
            trip_updates: List[Dict[str, Any]] = []
            alerts: List[Dict[str, Any]] = []

            for entity in feed.entity:
                report.total_records += 1

                # 1. Vehicle Positions
                if entity.HasField("vehicle"):
                    v = entity.vehicle
                    v_id = v.vehicle.id if v.HasField("vehicle") and v.vehicle.id else entity.id
                    lat = v.position.latitude
                    lon = v.position.longitude

                    # Validate coordinates
                    if 41.0 <= lat <= 44.5 and -4.5 <= lon <= -1.0:
                        obs_ts = datetime.fromtimestamp(v.timestamp, tz=timezone.utc) if v.timestamp else header_dt
                        status_str = None
                        if v.current_status == gtfs_realtime_pb2.VehiclePosition.INCOMING_AT:
                            status_str = "INCOMING_AT"
                        elif v.current_status == gtfs_realtime_pb2.VehiclePosition.STOPPED_AT:
                            status_str = "STOPPED_AT"
                        elif v.current_status == gtfs_realtime_pb2.VehiclePosition.IN_TRANSIT_TO:
                            status_str = "IN_TRANSIT_TO"

                        vehicles.append({
                            "id": str(uuid.uuid4()),
                            "operator_id": operator_id,
                            "vehicle_id": v_id,
                            "vehicle_label": v.vehicle.label if v.HasField("vehicle") else None,
                            "license_plate": v.vehicle.license_plate if v.HasField("vehicle") else None,
                            "external_trip_id": v.trip.trip_id if v.HasField("trip") else None,
                            "external_route_id": v.trip.route_id if v.HasField("trip") else None,
                            "latitude": lat,
                            "longitude": lon,
                            "bearing": v.position.bearing if v.position.HasField("bearing") else None,
                            "speed": v.position.speed if v.position.HasField("speed") else None,
                            "current_stop_sequence": v.current_stop_sequence if v.HasField("current_stop_sequence") else None,
                            "current_status": status_str,
                            "timestamp": obs_ts,
                            "is_latest": True
                        })
                        report.valid_records += 1
                    else:
                        report.rejected_records += 1
                        report.errors.append(ValidationError("vehicle", str(v_id), f"Invalid vehicle coordinates: {lat}, {lon}"))

                # 2. Trip Updates
                elif entity.HasField("trip_update"):
                    tu = entity.trip_update
                    t_id = tu.trip.trip_id if tu.HasField("trip") else entity.id
                    upd_ts = datetime.fromtimestamp(tu.timestamp, tz=timezone.utc) if tu.timestamp else header_dt

                    trip_updates.append({
                        "id": str(uuid.uuid4()),
                        "operator_id": operator_id,
                        "external_trip_id": t_id,
                        "external_route_id": tu.trip.route_id if tu.HasField("trip") else None,
                        "vehicle_id": tu.vehicle.id if tu.HasField("vehicle") else None,
                        "start_time": tu.trip.start_time if tu.HasField("trip") else None,
                        "start_date": tu.trip.start_date if tu.HasField("trip") else None,
                        "timestamp": upd_ts,
                        "delay_seconds": tu.delay if tu.HasField("delay") else None
                    })
                    report.valid_records += 1

                # 3. Service Alerts
                elif entity.HasField("alert"):
                    al = entity.alert
                    cause_name = gtfs_realtime_pb2.Alert.Cause.Name(al.cause) if al.HasField("cause") else "UNKNOWN_CAUSE"
                    effect_name = gtfs_realtime_pb2.Alert.Effect.Name(al.effect) if al.HasField("effect") else "UNKNOWN_EFFECT"

                    headers_map = {}
                    if al.HasField("header_text"):
                        for trans in al.header_text.translation:
                            headers_map[trans.language or "es"] = trans.text

                    desc_map = {}
                    if al.HasField("description_text"):
                        for trans in al.description_text.translation:
                            desc_map[trans.language or "es"] = trans.text

                    alerts.append({
                        "id": str(uuid.uuid4()),
                        "operator_id": operator_id,
                        "external_alert_id": entity.id,
                        "cause": cause_name,
                        "effect": effect_name,
                        "header_text": headers_map,
                        "description_text": desc_map,
                        "is_active": True
                    })
                    report.valid_records += 1

            report.metrics["vehicles_parsed"] = len(vehicles)
            report.metrics["trip_updates_parsed"] = len(trip_updates)
            report.metrics["alerts_parsed"] = len(alerts)

            if context.get("persist_to_db", False):
                self._persist_realtime(operator_id, vehicles, trip_updates, alerts)

            report.mark_completed()
            return report

        except Exception as e:
            report.rejected_records += 1
            report.errors.append(ValidationError("protobuf", file_path, f"Failed decoding protobuf: {e}"))
            report.mark_completed("failed")
            logger.error(f"GTFS-RT decode error: {e}")
            return report

    def _persist_realtime(
        self,
        operator_id: str,
        vehicles: List[Dict[str, Any]],
        trip_updates: List[Dict[str, Any]],
        alerts: List[Dict[str, Any]]
    ):
        """Persists real-time observations into Supabase PostgreSQL."""
        with get_db_session() as session:
            # Mark previous positions for this operator as not latest
            if vehicles:
                session.execute(
                    text("UPDATE public.vehicle_positions SET is_latest = false WHERE operator_id = :op_id AND is_latest = true"),
                    {"op_id": operator_id}
                )
                insert_veh_sql = text("""
                    INSERT INTO public.vehicle_positions (
                        id, operator_id, vehicle_id, vehicle_label, license_plate,
                        external_trip_id, external_route_id, latitude, longitude,
                        geom, bearing, speed, current_stop_sequence, current_status,
                        timestamp, is_latest
                    ) VALUES (
                        :id, :operator_id, :vehicle_id, :vehicle_label, :license_plate,
                        :external_trip_id, :external_route_id, :latitude, :longitude,
                        ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326),
                        :bearing, :speed, :current_stop_sequence, :current_status,
                        :timestamp, :is_latest
                    );
                """)
                session.execute(insert_veh_sql, vehicles)

            if trip_updates:
                insert_tu_sql = text("""
                    INSERT INTO public.trip_updates (
                        id, operator_id, external_trip_id, external_route_id,
                        vehicle_id, start_time, start_date, timestamp, delay_seconds
                    ) VALUES (
                        :id, :operator_id, :external_trip_id, :external_route_id,
                        :vehicle_id, :start_time, :start_date, :timestamp, :delay_seconds
                    );
                """)
                session.execute(insert_tu_sql, trip_updates)

            if alerts:
                import json
                for al in alerts:
                    session.execute(
                        text("""
                            INSERT INTO public.service_alerts (
                                id, operator_id, external_alert_id, cause, effect,
                                header_text, description_text, is_active, updated_at
                            ) VALUES (
                                :id, :operator_id, :external_alert_id, :cause, :effect,
                                :header_text::jsonb, :description_text::jsonb, :is_active, now()
                            ) ON CONFLICT (operator_id, external_alert_id) DO UPDATE SET
                                cause = excluded.cause,
                                effect = excluded.effect,
                                header_text = excluded.header_text,
                                description_text = excluded.description_text,
                                is_active = excluded.is_active,
                                updated_at = now();
                        """),
                        {
                            "id": al["id"],
                            "operator_id": al["operator_id"],
                            "external_alert_id": al["external_alert_id"],
                            "cause": al["cause"],
                            "effect": al["effect"],
                            "header_text": json.dumps(al["header_text"]),
                            "description_text": json.dumps(al["description_text"]),
                            "is_active": al["is_active"]
                        }
                    )
