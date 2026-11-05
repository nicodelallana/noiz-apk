#!/usr/bin/env python3
"""
Official Euskadi Transit GTFS Compiler
======================================
Compiles official GTFS feeds from Open Data Euskadi (Moveuskadi) for all
35 operators across Bizkaia, Gipuzkoa, and Araba into an offline, indexed
SQLite database (transit.sqlite), compresses it with gzip (transit.sqlite.gz),
and generates manifest.json.

Ensures:
- 100% official data (stops, routes, shapes, trips, stop_times, calendar).
- Zero fake, random, or synthetic schedules.
- Correct namespacing to prevent ID collisions: {operator_id}:{item_id}.
- Accurate geographic bounds and mode mapping.
- Polyline coordinates stored as compact JSON in `shapes` table.
"""

import csv
import gzip
import hashlib
import io
import json
import math
import os
import re
import shutil
import sqlite3
import ssl
import sys
import time
import urllib.request
import zipfile
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

CATALOG_URL = "https://opendata.euskadi.eus/transport/moveuskadi/data-index.json"

# Territory bounds: Basque Country and relevant cross-border / regional connections
LAT_MIN, LAT_MAX = 41.5, 44.0
LON_MIN, LON_MAX = -4.0, -1.0

# Operator metadata configurations
OPERATOR_CONFIGS = {
    "Metro Bilbao": {
        "id": "metro",
        "name": "Metro Bilbao",
        "territory": "bizkaia",
        "mode": "metro",
        "color": "#E8590C",
        "has_realtime": 1,
    },
    "BizkaiBus": {
        "id": "bizkaibus",
        "name": "Bizkaibus",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#2E9E4F",
        "has_realtime": 1,
    },
    "BilboBus": {
        "id": "bilbobus",
        "name": "Bilbobus",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#D7143C",
        "has_realtime": 1,
    },
    "Euskotren": {
        "id": "euskotren",
        "name": "Euskotren",
        "territory": "bizkaia",
        "mode": "train",
        "color": "#025DA9",
        "has_realtime": 1,
    },
    "RENFE Cercanias": {
        "id": "renfe",
        "name": "Renfe Cercanías",
        "territory": "bizkaia",
        "mode": "train",
        "color": "#D0142B",
        "has_realtime": 1,
    },
    "RENFE Media": {
        "id": "renfe_media",
        "name": "Renfe Media Distancia",
        "territory": "bizkaia",
        "mode": "train",
        "color": "#8B1E41",
        "has_realtime": 0,
    },
    "Dbus": {
        "id": "dbus",
        "name": "Dbus",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#1D7FD1",
        "has_realtime": 1,
    },
    "Tuvisa": {
        "id": "tuvisa",
        "name": "TUVISA",
        "territory": "araba",
        "mode": "bus",
        "color": "#12979F",
        "has_realtime": 1,
    },
    "AlavaBus": {
        "id": "alavabus",
        "name": "Álavabus",
        "territory": "araba",
        "mode": "bus",
        "color": "#B04A8E",
        "has_realtime": 0,
    },
    "La Unión": {
        "id": "la_union",
        "name": "La Unión",
        "territory": "araba",
        "mode": "bus",
        "color": "#30609D",
        "has_realtime": 0,
    },
    "Funicular Artxanda": {
        "id": "artxanda",
        "name": "Funicular de Artxanda",
        "territory": "bizkaia",
        "mode": "funicular",
        "color": "#DC0B0B",
        "has_realtime": 0,
    },
    "Puente Colgante": {
        "id": "pte_colgante",
        "name": "Puente Colgante",
        "territory": "bizkaia",
        "mode": "funicular",
        "color": "#8A3B14",
        "has_realtime": 0,
    },
    # Lurraldebus operators
    "Pesa (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Pesa)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Ekialdebus (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Ekialdebus)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Guipuzkoana (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Guipuzkoana)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Euskotren bus (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Euskotren)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Goierrialdea (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Goierrialdea)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Tolosaldea (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (Tolosaldea)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Tbh (Lurraldebus)": {
        "id": "lurraldebus",
        "name": "Lurraldebus (TBH)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 1,
    },
    "Urbano de Tolosa": {
        "id": "lurraldebus",
        "name": "Tolosa Urbanoa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#5E9424",
        "has_realtime": 0,
    },
    # Local urban buses in Bizkaia
    "Kbus": {
        "id": "kbus",
        "name": "Kbus (Barakaldo)",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#008080",
        "has_realtime": 0,
    },
    "EtxeBarriBus": {
        "id": "etxebarribus",
        "name": "EtxeBarriBus",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#4A90E2",
        "has_realtime": 0,
    },
    "Erandio! busa": {
        "id": "erandio_busa",
        "name": "Erandio! Busa",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#F5A623",
        "has_realtime": 0,
    },
    "Lejoan busa": {
        "id": "lejoan_busa",
        "name": "Leioabus",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#7ED321",
        "has_realtime": 0,
    },
    "Sopelbus": {
        "id": "sopelbus",
        "name": "Sopelbus",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#9013FE",
        "has_realtime": 0,
    },
    "Bermibusa": {
        "id": "bermibusa",
        "name": "Bermibusa",
        "territory": "bizkaia",
        "mode": "bus",
        "color": "#50E3C2",
        "has_realtime": 0,
    },
    # Local urban buses in Gipuzkoa
    "Irunbus": {
        "id": "irunbus",
        "name": "Irunbus",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#BD10E0",
        "has_realtime": 0,
    },
    "Zarauzko hiribusa": {
        "id": "zarauzko_hiribusa",
        "name": "Zarauzko Hiribusa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#417505",
        "has_realtime": 0,
    },
    "Hernaniko hiribusa": {
        "id": "hernaniko_hiribusa",
        "name": "Hernaniko Hiribusa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#B8E986",
        "has_realtime": 0,
    },
    "Errenteria Urbanoa": {
        "id": "errenteria",
        "name": "Errenteria Urbanoa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#D0021B",
        "has_realtime": 0,
    },
    "Udalbus (Eibar)": {
        "id": "eibar",
        "name": "Udalbus (Eibar)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#4A4A4A",
        "has_realtime": 0,
    },
    "Oñati": {
        "id": "onati",
        "name": "Oñati Hiribusa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#9B9B9B",
        "has_realtime": 0,
    },
    "Xorrola (Oiartzun)": {
        "id": "oiartzun",
        "name": "Xorrola (Oiartzun)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#F8E71C",
        "has_realtime": 0,
    },
    "Arrasate": {
        "id": "arrasate",
        "name": "Arrasate Hiribusa",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#E67E22",
        "has_realtime": 0,
    },
    "Lasarte (Muittu Manttangorri)": {
        "id": "lasarte",
        "name": "Manttangorri (Lasarte)",
        "territory": "gipuzkoa",
        "mode": "bus",
        "color": "#1ABC9C",
        "has_realtime": 0,
    },
}

def log(msg: str):
    print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {msg}", flush=True)

def init_database(db_path: str) -> sqlite3.Connection:
    if os.path.exists(db_path):
        os.remove(db_path)
    os.makedirs(os.path.dirname(db_path), exist_ok=True)

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode = OFF;")
    cur.execute("PRAGMA synchronous = 0;")
    cur.execute("PRAGMA cache_size = 100000;")
    cur.execute("PRAGMA temp_store = MEMORY;")

    cur.executescript("""
    CREATE TABLE operators (
        operator_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        territory TEXT NOT NULL DEFAULT 'bizkaia',
        mode TEXT NOT NULL DEFAULT 'bus',
        color_hex TEXT NOT NULL DEFAULT '#025DA9',
        has_realtime INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE routes (
        route_id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        route_short_name TEXT NOT NULL,
        route_long_name TEXT NOT NULL,
        route_type INTEGER NOT NULL,
        route_color TEXT,
        territory TEXT NOT NULL DEFAULT 'bizkaia'
    );

    CREATE TABLE stops (
        stop_id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        stop_name TEXT NOT NULL,
        stop_lat REAL NOT NULL,
        stop_lon REAL NOT NULL,
        zone_id TEXT,
        parent_station TEXT,
        territory TEXT NOT NULL DEFAULT 'bizkaia',
        mode TEXT NOT NULL DEFAULT 'bus',
        location_type INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE shapes (
        shape_id TEXT PRIMARY KEY,
        points_json TEXT NOT NULL
    );

    CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        direction_id INTEGER,
        shape_id TEXT,
        inferred_line TEXT
    );

    CREATE TABLE stop_times (
        trip_id TEXT NOT NULL,
        stop_id TEXT NOT NULL,
        stop_sequence INTEGER NOT NULL,
        arrival_time TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        PRIMARY KEY (trip_id, stop_sequence)
    );

    CREATE TABLE calendar (
        service_id TEXT PRIMARY KEY,
        monday INTEGER NOT NULL,
        tuesday INTEGER NOT NULL,
        wednesday INTEGER NOT NULL,
        thursday INTEGER NOT NULL,
        friday INTEGER NOT NULL,
        saturday INTEGER NOT NULL,
        sunday INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
    );

    CREATE TABLE calendar_dates (
        service_id TEXT NOT NULL,
        date TEXT NOT NULL,
        exception_type INTEGER NOT NULL,
        PRIMARY KEY (service_id, date)
    );

    CREATE TABLE user_saved_trips (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        origin_stop_id TEXT NOT NULL,
        origin_stop_name TEXT NOT NULL,
        dest_stop_id TEXT NOT NULL,
        dest_stop_name TEXT NOT NULL,
        route_id TEXT,
        direction_id INTEGER,
        widget_enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
    );
    """)
    conn.commit()
    return conn

def rdp_simplify(points: List[List[float]], epsilon: float = 0.00005) -> List[List[float]]:
    """
    Ramer-Douglas-Peucker iterative polyline simplification.
    Reduces redundant points along straight segments while strictly preserving geometry.
    Epsilon is in degrees (~0.00005 deg ≈ 5.5 meters).
    """
    if len(points) <= 2:
        return points

    keep = [False] * len(points)
    keep[0] = True
    keep[-1] = True

    stack = [(0, len(points) - 1)]
    while stack:
        start_idx, end_idx = stack.pop()
        start = points[start_idx]
        end = points[end_idx]

        dmax = 0.0
        index = -1

        dx = end[0] - start[0]
        dy = end[1] - start[1]
        line_len = math.hypot(dx, dy)

        for i in range(start_idx + 1, end_idx):
            pt = points[i]
            if line_len == 0.0:
                dist = math.hypot(pt[0] - start[0], pt[1] - start[1])
            else:
                dist = abs(dy * pt[0] - dx * pt[1] + end[0] * start[1] - end[1] * start[0]) / line_len
            if dist > dmax:
                dmax = dist
                index = i

        if dmax > epsilon and index != -1:
            keep[index] = True
            stack.append((start_idx, index))
            stack.append((index, end_idx))

    return [points[i] for i in range(len(points)) if keep[i]]

def build_indices(conn: sqlite3.Connection):
    cur = conn.cursor()
    log("Backfilling missing trip headsigns and inferred lines...")
    cur.execute("""
        UPDATE trips 
        SET trip_headsign = (
            SELECT s.stop_name 
            FROM stop_times st 
            JOIN stops s ON st.stop_id = s.stop_id 
            WHERE st.trip_id = trips.trip_id 
            ORDER BY st.stop_sequence DESC 
            LIMIT 1
        )
        WHERE trip_headsign IS NULL OR trim(trip_headsign) = '';
    """)
    cur.execute("""
        UPDATE trips 
        SET inferred_line = (
            SELECT COALESCE(NULLIF(r.route_short_name, ''), r.route_long_name)
            FROM routes r 
            WHERE r.route_id = trips.route_id
        )
        WHERE inferred_line IS NULL OR trim(inferred_line) = '';
    """)
    conn.commit()

    log("Building high-performance SQLite indexes...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_operator ON stops (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_coords ON stops (stop_lat, stop_lon);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_parent ON stops (parent_station);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_mode ON stops (mode);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_routes_operator ON routes (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_route ON trips (route_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_service ON trips (service_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_shape ON trips (shape_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stop_times_lookup ON stop_times (stop_id, departure_time);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_calendar_dates_date ON calendar_dates (date);")
    conn.commit()

def fetch_feed_catalog() -> Dict[str, str]:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(CATALOG_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        data = json.loads(resp.read().decode("utf-8"))["data"]

    catalog = {}
    for op_name, resources in data.items():
        gtfs_res = next((r for r in resources if r.get("format") == "GTFS"), None)
        if gtfs_res and gtfs_res.get("url"):
            catalog[op_name] = gtfs_res.get("url")
    return catalog

def read_csv_from_zip(z: zipfile.ZipFile, filename: str) -> List[Dict[str, str]]:
    if filename not in z.namelist():
        return []
    with z.open(filename) as f:
        reader = csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig", errors="replace"))
        return [dict((k.strip().strip("'\""), (v.strip() if v else "")) for k, v in row.items() if k) for row in reader]

def process_operator_feed(
    conn: sqlite3.Connection,
    op_name: str,
    feed_url: str,
    cfg: Dict[str, Any]
) -> Dict[str, int]:
    op_id = cfg["id"]
    base_territory = cfg["territory"]
    default_mode = cfg["mode"]
    color = cfg["color"]

    log(f"Processing '{op_name}' (operator_id={op_id}) from {feed_url}...")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    req = urllib.request.Request(feed_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
        zip_bytes = resp.read()

    z = zipfile.ZipFile(io.BytesIO(zip_bytes))
    cur = conn.cursor()

    # 1. Operators table entry
    cur.execute("""
        INSERT OR IGNORE INTO operators (operator_id, name, territory, mode, color_hex, has_realtime)
        VALUES (?, ?, ?, ?, ?, ?);
    """, (op_id, cfg["name"], base_territory, default_mode, color, cfg["has_realtime"]))

    # 2. Routes
    raw_routes = read_csv_from_zip(z, "routes.txt")
    valid_route_ids: Set[str] = set()
    routes_rows = []

    for r in raw_routes:
        raw_r_id = r.get("route_id", "")
        if not raw_r_id:
            continue

        # If Renfe Cercanías, filter to Basque Country corridors (60T... and 61T...)
        if op_id == "renfe" and not (raw_r_id.startswith("60T") or raw_r_id.startswith("61T")):
            continue

        namespaced_r_id = f"{op_id}:{raw_r_id}"
        valid_route_ids.add(raw_r_id)

        short_name = r.get("route_short_name") or ""
        long_name = r.get("route_long_name") or short_name
        if not short_name and long_name:
            short_name = long_name[:10]

        r_type_str = r.get("route_type", "3")
        try:
            r_type = int(r_type_str)
        except ValueError:
            r_type = 3

        r_color = r.get("route_color")
        if r_color:
            r_color = f"#{r_color.lstrip('#')}"
        else:
            r_color = color

        routes_rows.append((
            namespaced_r_id,
            op_id,
            short_name,
            long_name,
            r_type,
            r_color,
            base_territory
        ))

    cur.executemany("""
        INSERT OR REPLACE INTO routes (route_id, operator_id, route_short_name, route_long_name, route_type, route_color, territory)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    """, routes_rows)

    # 3. Shapes (points_json)
    shapes_dict: Dict[str, List[Tuple[int, float, float]]] = {}
    if "shapes.txt" in z.namelist():
        raw_shapes = read_csv_from_zip(z, "shapes.txt")
        for sh in raw_shapes:
            sh_id = sh.get("shape_id")
            lat_str = sh.get("shape_pt_lat")
            lon_str = sh.get("shape_pt_lon")
            seq_str = sh.get("shape_pt_sequence")
            if not sh_id or not lat_str or not lon_str or seq_str is None:
                continue
            try:
                lat = float(lat_str)
                lon = float(lon_str)
                seq = int(seq_str)
                if sh_id not in shapes_dict:
                    shapes_dict[sh_id] = []
                shapes_dict[sh_id].append((seq, lon, lat))
            except ValueError:
                continue

    shapes_rows = []
    for raw_sh_id, pt_list in shapes_dict.items():
        pt_list.sort(key=lambda x: x[0])
        # Format as [[lon, lat], [lon, lat], ...] for MapLibre GeoJSON LineString
        coords = [[round(lon, 6), round(lat, 6)] for _, lon, lat in pt_list]
        simplified_coords = rdp_simplify(coords, epsilon=0.00005)
        shapes_rows.append((f"{op_id}:{raw_sh_id}", json.dumps(simplified_coords, separators=(',', ':'))))

    cur.executemany("""
        INSERT OR REPLACE INTO shapes (shape_id, points_json)
        VALUES (?, ?);
    """, shapes_rows)

    # 4. Trips
    raw_trips = read_csv_from_zip(z, "trips.txt")
    valid_trip_ids: Set[str] = set()
    trips_rows = []

    for t in raw_trips:
        raw_t_id = t.get("trip_id")
        raw_r_id = t.get("route_id")
        raw_s_id = t.get("service_id")
        if not raw_t_id or not raw_r_id or not raw_s_id:
            continue
        if raw_r_id not in valid_route_ids:
            continue

        valid_trip_ids.add(raw_t_id)
        namespaced_t_id = f"{op_id}:{raw_t_id}"
        namespaced_r_id = f"{op_id}:{raw_r_id}"
        namespaced_s_id = f"{op_id}:{raw_s_id}"

        headsign = t.get("trip_headsign")
        dir_str = t.get("direction_id")
        dir_id = int(dir_str) if dir_str in ("0", "1") else 0
        raw_sh_id = t.get("shape_id")
        namespaced_sh_id = f"{op_id}:{raw_sh_id}" if raw_sh_id else None

        # Determine inferred line name
        inferred = headsign or op_id.upper()
        trips_rows.append((
            namespaced_t_id,
            namespaced_r_id,
            namespaced_s_id,
            headsign,
            dir_id,
            namespaced_sh_id,
            inferred
        ))

    cur.executemany("""
        INSERT OR REPLACE INTO trips (trip_id, route_id, service_id, trip_headsign, direction_id, shape_id, inferred_line)
        VALUES (?, ?, ?, ?, ?, ?, ?);
    """, trips_rows)

    # 5. Stop Times
    raw_stop_times = read_csv_from_zip(z, "stop_times.txt")
    stop_times_rows = []
    used_stop_ids: Set[str] = set()

    for st in raw_stop_times:
        raw_t_id = st.get("trip_id")
        raw_s_id = st.get("stop_id")
        seq_str = st.get("stop_sequence")
        arr = st.get("arrival_time")
        dep = st.get("departure_time")

        if not raw_t_id or not raw_s_id or seq_str is None or not arr or not dep:
            continue
        if raw_t_id not in valid_trip_ids:
            continue

        try:
            seq = int(seq_str)
            namespaced_t_id = f"{op_id}:{raw_t_id}"
            namespaced_s_id = f"{op_id}:{raw_s_id}"
            used_stop_ids.add(raw_s_id)
            stop_times_rows.append((
                namespaced_t_id,
                namespaced_s_id,
                seq,
                arr,
                dep
            ))
        except ValueError:
            continue

    cur.executemany("""
        INSERT OR REPLACE INTO stop_times (trip_id, stop_id, stop_sequence, arrival_time, departure_time)
        VALUES (?, ?, ?, ?, ?);
    """, stop_times_rows)

    # 6. Stops
    raw_stops = read_csv_from_zip(z, "stops.txt")
    stops_rows = []

    for s in raw_stops:
        raw_s_id = s.get("stop_id")
        name = s.get("stop_name")
        lat_str = s.get("stop_lat")
        lon_str = s.get("stop_lon")
        if not raw_s_id or not name or not lat_str or not lon_str:
            continue

        try:
            lat = float(lat_str)
            lon = float(lon_str)
            # Geographic filter: Keep stops in and around Basque Country
            if not (LAT_MIN <= lat <= LAT_MAX and LON_MIN <= lon <= LON_MAX):
                # For Renfe Cercanias, skip stops outside Basque Country
                if op_id in ("renfe", "renfe_media"):
                    continue

            namespaced_s_id = f"{op_id}:{raw_s_id}"
            raw_parent = s.get("parent_station")
            namespaced_parent = f"{op_id}:{raw_parent}" if raw_parent else None

            loc_type_str = s.get("location_type", "0")
            try:
                loc_type = int(loc_type_str) if loc_type_str else 0
            except ValueError:
                loc_type = 0

            # Determine stop mode
            mode = default_mode
            if op_id == "euskotren":
                if "tranbia" in name.lower() or "tram" in name.lower():
                    mode = "tram"
                elif "funicular" in name.lower():
                    mode = "funicular"

            stops_rows.append((
                namespaced_s_id,
                op_id,
                name,
                lat,
                lon,
                s.get("zone_id"),
                namespaced_parent,
                base_territory,
                mode,
                loc_type
            ))
        except ValueError:
            continue

    cur.executemany("""
        INSERT OR REPLACE INTO stops (stop_id, operator_id, stop_name, stop_lat, stop_lon, zone_id, parent_station, territory, mode, location_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, stops_rows)

    # 7. Calendars & Calendar Exceptions
    raw_calendar = read_csv_from_zip(z, "calendar.txt")
    calendar_rows = []
    for c in raw_calendar:
        raw_s_id = c.get("service_id")
        if not raw_s_id:
            continue
        try:
            calendar_rows.append((
                f"{op_id}:{raw_s_id}",
                int(c.get("monday", 0)),
                int(c.get("tuesday", 0)),
                int(c.get("wednesday", 0)),
                int(c.get("thursday", 0)),
                int(c.get("friday", 0)),
                int(c.get("saturday", 0)),
                int(c.get("sunday", 0)),
                c.get("start_date", ""),
                c.get("end_date", "")
            ))
        except ValueError:
            continue

    cur.executemany("""
        INSERT OR REPLACE INTO calendar (service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, calendar_rows)

    raw_calendar_dates = read_csv_from_zip(z, "calendar_dates.txt")
    cal_dates_rows = []
    for cd in raw_calendar_dates:
        raw_s_id = cd.get("service_id")
        d_str = cd.get("date")
        t_str = cd.get("exception_type")
        if not raw_s_id or not d_str or not t_str:
            continue
        try:
            cal_dates_rows.append((
                f"{op_id}:{raw_s_id}",
                d_str,
                int(t_str)
            ))
        except ValueError:
            continue

    cur.executemany("""
        INSERT OR REPLACE INTO calendar_dates (service_id, date, exception_type)
        VALUES (?, ?, ?);
    """, cal_dates_rows)

    conn.commit()
    log(f"-> '{op_name}' finished: {len(stops_rows)} stops, {len(routes_rows)} routes, {len(shapes_rows)} shapes, {len(trips_rows)} trips, {len(stop_times_rows)} stop_times.")
    return {
        "stops": len(stops_rows),
        "routes": len(routes_rows),
        "shapes": len(shapes_rows),
        "trips": len(trips_rows),
        "stop_times": len(stop_times_rows)
    }

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out_dir = os.path.join(root_dir, "tools", "build_gtfs", "out")
    assets_db_dir = os.path.join(root_dir, "assets", "db")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(assets_db_dir, exist_ok=True)

    db_path = os.path.join(out_dir, "transit.sqlite")
    gz_path = os.path.join(out_dir, "transit.sqlite.gz")
    manifest_path = os.path.join(out_dir, "manifest.json")
    bundled_db_path = os.path.join(assets_db_dir, "transit.sqlite")

    log("Starting Official Moveuskadi GTFS Compiler...")
    conn = init_database(db_path)

    log("Fetching authoritative feed catalog from Open Data Euskadi...")
    catalog = fetch_feed_catalog()
    log(f"Discovered {len(catalog)} feeds in catalog.")

    total_stats = {"stops": 0, "routes": 0, "shapes": 0, "trips": 0, "stop_times": 0}

    for op_name, feed_url in catalog.items():
        cfg = OPERATOR_CONFIGS.get(op_name)
        if not cfg:
            # Match by substring or default
            clean_name = op_name.strip()
            cfg = {
                "id": re.sub(r"[^\w]+", "_", clean_name).strip("_").lower(),
                "name": clean_name,
                "territory": "bizkaia" if "bilbao" in clean_name.lower() or "bizkai" in clean_name.lower() else ("gipuzkoa" if "donostia" in clean_name.lower() or "gipuzkoa" in clean_name.lower() or "lurraldebus" in clean_name.lower() else "araba"),
                "mode": "bus",
                "color": "#025DA9",
                "has_realtime": 0
            }

        try:
            stats = process_operator_feed(conn, op_name, feed_url, cfg)
            for k in total_stats:
                total_stats[k] += stats.get(k, 0)
        except Exception as e:
            log(f"ERROR processing {op_name}: {e}")

    # Build SQLite indexes
    build_indices(conn)

    log("Compacting and vacuuming SQLite database...")
    conn.execute("VACUUM;")

    cur = conn.cursor()
    total_stops = cur.execute("SELECT count(*) FROM stops;").fetchone()[0]
    total_routes = cur.execute("SELECT count(*) FROM routes;").fetchone()[0]
    total_trips = cur.execute("SELECT count(*) FROM trips;").fetchone()[0]
    total_shapes = cur.execute("SELECT count(*) FROM shapes;").fetchone()[0]
    total_stop_times = cur.execute("SELECT count(*) FROM stop_times;").fetchone()[0]
    conn.close()

    log("--- COMPILATION COMPLETE ---")
    log(f"Total Stops: {total_stops}")
    log(f"Total Routes: {total_routes}")
    log(f"Total Shapes: {total_shapes}")
    log(f"Total Trips: {total_trips}")
    log(f"Total Stop Times: {total_stop_times}")

    # Copy to assets/db/transit.sqlite
    log(f"Copying compiled DB to bundled asset: {bundled_db_path}...")
    shutil.copyfile(db_path, bundled_db_path)

    # Compress to gzip
    log(f"Compressing to {gz_path}...")
    with open(db_path, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        shutil.copyfileobj(f_in, f_out)

    def sha256_file(filepath: str) -> str:
        h = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()

    db_bytes = os.path.getsize(db_path)
    db_hash = sha256_file(db_path)
    gz_bytes = os.path.getsize(gz_path)
    gz_hash = sha256_file(gz_path)

    manifest = {
        "version": "4.0.0-moveuskadi-official",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_stops": total_stops,
        "total_routes": total_routes,
        "total_shapes": total_shapes,
        "sqlite": {
            "filename": os.path.basename(db_path),
            "bytes": db_bytes,
            "sha256": db_hash,
        },
        "compressed": {
            "filename": os.path.basename(gz_path),
            "bytes": gz_bytes,
            "sha256": gz_hash,
        }
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    log(f"Manifest written to {manifest_path}.")
    log(f"Database size: {db_bytes / (1024*1024):.2f} MB (uncompressed), {gz_bytes / (1024*1024):.2f} MB (gzip).")

if __name__ == "__main__":
    main()
