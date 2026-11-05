#!/usr/bin/env python3
"""
Euskadi Multi-Operator GTFS Static Schedule Compiler
=====================================================
Downloads and compiles authoritative GTFS Static feeds from Moveuskadi
(all 35 transport operators across Bizkaia, Gipuzkoa, and Araba) into
a compact, optimized SQLite database (transit.sqlite), compresses it
(transit.sqlite.gz), and generates manifest.json for Supabase Storage.
"""

import csv
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

# Official Moveuskadi Dynamic Index
MOVEUSKADI_INDEX_URL = "https://opendata.euskadi.eus/transport/moveuskadi/data-index.json"

# Geographic bounding box for Basque Country + direct connections (Miranda, Castro, Logroño, Hendaia)
MIN_LAT = 42.30
MAX_LAT = 43.65
MIN_LON = -3.55
MAX_LON = -1.65

# Operator definitions matching Flutter's TransitOperator enum
OPERATOR_CATALOG = {
    # Bizkaia
    "metro": {
        "name": "Metro Bilbao", "territory": "bizkaia", "mode": "metro",
        "color_hex": "#E8590C", "has_realtime": 1
    },
    "bizkaibus": {
        "name": "Bizkaibus", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#2E9E4F", "has_realtime": 1
    },
    "bilbobus": {
        "name": "Bilbobus", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#D7143C", "has_realtime": 1
    },
    "renfe": {
        "name": "Renfe Cercanías", "territory": "bizkaia", "mode": "train",
        "color_hex": "#D0142B", "has_realtime": 1
    },
    "euskotren": {
        "name": "Euskotren", "territory": "bizkaia", "mode": "train",
        "color_hex": "#025DA9", "has_realtime": 1
    },
    "tranbia_bilbao": {
        "name": "Tranvía de Bilbao", "territory": "bizkaia", "mode": "tram",
        "color_hex": "#2FA650", "has_realtime": 1
    },
    "artxanda": {
        "name": "Funicular de Artxanda", "territory": "bizkaia", "mode": "funicular",
        "color_hex": "#DC0B0B", "has_realtime": 0
    },
    "pte_colgante": {
        "name": "Puente Colgante", "territory": "bizkaia", "mode": "funicular",
        "color_hex": "#8D6E63", "has_realtime": 0
    },
    "kbus": {
        "name": "Kbus (Barakaldo)", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#2B5B84", "has_realtime": 1
    },
    "etxebarribus": {
        "name": "EtxeBarriBus", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#007A3D", "has_realtime": 1
    },
    "erandio_busa": {
        "name": "Erandio! busa", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#00897B", "has_realtime": 1
    },
    "lejoan_busa": {
        "name": "Lejoan busa", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#5C6BC0", "has_realtime": 1
    },
    "sopelbus": {
        "name": "Sopelbus", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#00ACC1", "has_realtime": 1
    },
    "bermibusa": {
        "name": "Bermibusa", "territory": "bizkaia", "mode": "bus",
        "color_hex": "#1E88E5", "has_realtime": 1
    },

    # Gipuzkoa
    "dbus": {
        "name": "Dbus", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#1D7FD1", "has_realtime": 1
    },
    "lurraldebus": {
        "name": "Lurraldebus", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#5E9424", "has_realtime": 1
    },
    "irunbus": {
        "name": "Irunbus", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#0072CE", "has_realtime": 0
    },
    "errenteria": {
        "name": "Errenteria Urbanoa", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#3949AB", "has_realtime": 1
    },
    "zarauzko_hiribusa": {
        "name": "Zarauzko hiribusa", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#0097A7", "has_realtime": 1
    },
    "hernaniko_hiribusa": {
        "name": "Hernaniko hiribusa", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#43A047", "has_realtime": 1
    },
    "tolosa": {
        "name": "Urbano de Tolosa", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#7CB342", "has_realtime": 1
    },
    "eibar": {
        "name": "Udalbus (Eibar)", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#8E24AA", "has_realtime": 1
    },
    "arrasate": {
        "name": "Arrasate", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#D81B60", "has_realtime": 1
    },
    "onati": {
        "name": "Oñati", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#546E7A", "has_realtime": 1
    },
    "lasarte": {
        "name": "Lasarte (Manttangorri)", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#E65100", "has_realtime": 0
    },
    "oiartzun": {
        "name": "Xorrola (Oiartzun)", "territory": "gipuzkoa", "mode": "bus",
        "color_hex": "#6D4C41", "has_realtime": 1
    },

    # Araba
    "tuvisa": {
        "name": "TUVISA", "territory": "araba", "mode": "bus",
        "color_hex": "#12979F", "has_realtime": 1
    },
    "alavabus": {
        "name": "Álavabus", "territory": "araba", "mode": "bus",
        "color_hex": "#B04A8E", "has_realtime": 0
    },
    "tranbia_gasteiz": {
        "name": "Tranvía de Vitoria-Gasteiz", "territory": "araba", "mode": "tram",
        "color_hex": "#2FA650", "has_realtime": 1
    },
    "la_union": {
        "name": "La Unión", "territory": "araba", "mode": "bus",
        "color_hex": "#30609D", "has_realtime": 0
    },
    "renfe_media": {
        "name": "Renfe Media Distancia", "territory": "araba", "mode": "train",
        "color_hex": "#7B1FA2", "has_realtime": 0
    },
}

# Mapping from Moveuskadi resource URL/slug to internal operator ID
MOVEUSKADI_TO_OPERATOR = {
    "metro_bilbao": "metro",
    "bizkaibus": "bizkaibus",
    "bilbobus": "bilbobus",
    "renfe_cercanias": "renfe",
    "renfe_media": "renfe_media",
    "euskotren_bus": "lurraldebus",
    "euskotren": "euskotren",
    "dbus": "dbus",
    "pesa": "lurraldebus",
    "ekialdebus": "lurraldebus",
    "goierrialdea": "lurraldebus",
    "guipuzkoana": "lurraldebus",
    "tbh": "lurraldebus",
    "tolosaldea": "lurraldebus",
    "tuvisa": "tuvisa",
    "alavabus": "alavabus",
    "funicular_artxanda": "artxanda",
    "pte_colgante": "pte_colgante",
    "la_union": "la_union",
    "kbus": "kbus",
    "etxebarribus": "etxebarribus",
    "erandio_busa": "erandio_busa",
    "lejoan_busa": "lejoan_busa",
    "sopelbus": "sopelbus",
    "bermibusa": "bermibusa",
    "irunbus": "irunbus",
    "errenteria": "errenteria",
    "zarauzko_hiribusa": "zarauzko_hiribusa",
    "hernaniko_hiribusa": "hernaniko_hiribusa",
    "tolosa": "tolosa",
    "eibar": "eibar",
    "arrasate": "arrasate",
    "onati": "onati",
    "muittu_manttangorri_lasarte": "lasarte",
    "oiartzun": "oiartzun",
}

def log(msg: str):
    print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {msg}", flush=True)

def resolve_operator_id(url: str, op_name: str) -> Optional[str]:
    url_lower = url.lower()
    for slug, op_id in MOVEUSKADI_TO_OPERATOR.items():
        if f"/{slug}/" in url_lower or f"_{slug}." in url_lower or slug in url_lower:
            return op_id
    clean_name = re.sub(r"[^\w]", "", op_name.lower())
    for slug, op_id in MOVEUSKADI_TO_OPERATOR.items():
        if clean_name in slug or slug in clean_name:
            return op_id
    return None

def fetch_feed_index() -> List[Tuple[str, str, str]]:
    """Returns list of (operator_id, operator_name, resource_url)."""
    log("Fetching Moveuskadi data-index.json...")
    req = urllib.request.Request(MOVEUSKADI_INDEX_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    operators = data.get("data", {})
    feeds = []
    for op_name, resources in operators.items():
        for res in resources:
            if str(res.get("format", "")).upper() == "GTFS":
                url = res.get("url")
                op_id = resolve_operator_id(url, op_name)
                if op_id and op_id in OPERATOR_CATALOG:
                    feeds.append((op_id, op_name, url))
                else:
                    log(f"Warning: could not resolve operator for {op_name} ({url})")
    log(f"Found {len(feeds)} official GTFS Static feeds in Moveuskadi catalog.")
    return feeds

def download_feeds(feeds: List[Tuple[str, str, str]], cache_dir: str) -> List[Tuple[str, str, str, str]]:
    """Downloads all feeds in parallel into cache_dir."""
    os.makedirs(cache_dir, exist_ok=True)
    results = []

    def download_one(item):
        op_id, op_name, url = item
        fname = os.path.basename(url.split("?")[0])
        target_path = os.path.join(cache_dir, f"{op_id}_{fname}")

        # Check if cached and fresh (< 24 hours)
        if os.path.exists(target_path) and (time.time() - os.path.getmtime(target_path) < 86400):
            return op_id, op_name, url, target_path

        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                with open(target_path, "wb") as f_out:
                    shutil.copyfileobj(resp, f_out)
            return op_id, op_name, url, target_path
        except Exception as e:
            log(f"Error downloading {op_name} ({url}): {e}")
            return op_id, op_name, url, None

    log(f"Downloading {len(feeds)} feeds in parallel with 8 threads...")
    with ThreadPoolExecutor(max_workers=8) as ex:
        for res in ex.map(download_one, feeds):
            if res[3] is not None and os.path.exists(res[3]):
                results.append(res)

    log(f"Successfully downloaded/cached {len(results)}/{len(feeds)} feed archives.")
    return results

def init_database(db_path: str) -> sqlite3.Connection:
    if os.path.exists(db_path):
        os.remove(db_path)

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
        mode TEXT NOT NULL DEFAULT 'metro',
        color_hex TEXT NOT NULL DEFAULT '#E8590C',
        has_realtime INTEGER NOT NULL DEFAULT 1
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

    CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        direction_id INTEGER,
        inferred_line TEXT,
        shape_id TEXT
    );

    CREATE TABLE shapes (
        shape_id TEXT PRIMARY KEY,
        points_json TEXT NOT NULL
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
    """)

    # Seed all official operators
    for op_id, meta in OPERATOR_CATALOG.items():
        cur.execute(
            "INSERT INTO operators VALUES (?, ?, ?, ?, ?, ?);",
            (op_id, meta["name"], meta["territory"], meta["mode"], meta["color_hex"], meta["has_realtime"])
        )

    conn.commit()
    return conn

def parse_csv_from_zip(zf: zipfile.ZipFile, filename: str) -> List[Dict[str, str]]:
    if filename not in zf.namelist():
        return []
    with zf.open(filename) as f:
        reader = csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig", errors="replace"))
        if not reader.fieldnames:
            return []
        cleaned_fields = [fn.strip() for fn in reader.fieldnames if fn]
        rows = []
        for line in reader:
            row = {k.strip().strip("'\""): (v.strip() if v else "") for k, v in line.items() if k}
            rows.append(row)
        return rows

def clean_stop_id(raw_id: str) -> str:
    return raw_id.strip()

def clean_coord(val: str) -> Optional[float]:
    try:
        return round(float(val.strip()), 6)
    except Exception:
        return None

def process_operator_feed(conn: sqlite3.Connection, op_id: str, zip_path: str):
    cur = conn.cursor()
    meta = OPERATOR_CATALOG[op_id]
    default_territory = meta["territory"]
    default_mode = meta["mode"]
    default_color = meta["color_hex"]

    log(f"Processing GTFS feed for {meta['name']} ({op_id})...")

    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            # 1. Stops
            raw_stops = parse_csv_from_zip(zf, "stops.txt")
            valid_stop_ids: Set[str] = set()
            stops_rows = []

            for s in raw_stops:
                raw_id = clean_stop_id(s.get("stop_id", ""))
                if not raw_id:
                    continue
                lat = clean_coord(s.get("stop_lat", ""))
                lon = clean_coord(s.get("stop_lon", ""))
                if lat is None or lon is None:
                    continue

                # Filter within Basque Country + border stations
                if not (MIN_LAT <= lat <= MAX_LAT and MIN_LON <= lon <= MAX_LON):
                    continue

                scoped_stop_id = f"{op_id}:{raw_id}"
                valid_stop_ids.add(scoped_stop_id)

                name = s.get("stop_name", "").strip() or f"Parada {raw_id}"
                zone = s.get("zone_id", "").strip() or None
                parent_raw = clean_stop_id(s.get("parent_station", ""))
                parent_station = f"{op_id}:{parent_raw}" if parent_raw else None
                loc_type = 1 if s.get("location_type", "").strip() == "1" else 0

                # Territory derivation based on coordinates if interprovincial
                stop_territory = default_territory
                if lon < -2.48 and lat > 43.10:
                    stop_territory = "bizkaia"
                elif lon >= -2.48 and lat >= 43.00:
                    stop_territory = "gipuzkoa"
                elif lat < 43.05:
                    stop_territory = "araba"

                stops_rows.append((
                    scoped_stop_id, op_id, name, lat, lon, zone,
                    parent_station, stop_territory, default_mode, loc_type
                ))

            if stops_rows:
                cur.executemany("INSERT OR REPLACE INTO stops VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", stops_rows)

            # 2. Routes
            raw_routes = parse_csv_from_zip(zf, "routes.txt")
            valid_route_ids: Set[str] = set()
            routes_rows = []

            for r in raw_routes:
                raw_r_id = r.get("route_id", "").strip()
                if not raw_r_id:
                    continue

                # Renfe Cercanías filter: only 60 (Bilbao) and 61 (Donostia)
                if op_id == "renfe" and not (raw_r_id.startswith("60") or raw_r_id.startswith("61")):
                    continue

                scoped_r_id = f"{op_id}:{raw_r_id}"
                valid_route_ids.add(scoped_r_id)

                short_name = r.get("route_short_name", "").strip()
                long_name = r.get("route_long_name", "").strip() or short_name

                # Route type
                try:
                    r_type = int(r.get("route_type", "3").strip())
                except Exception:
                    r_type = 3

                # Route color
                color = r.get("route_color", "").strip()
                if color:
                    color = f"#{color}" if not color.startswith("#") else color
                else:
                    color = default_color

                # Territory handling for routes
                r_territory = default_territory
                route_op_id = op_id

                # Special handling for Euskotren tranvías
                if op_id == "euskotren":
                    if r_type == 0 or "tranbia" in long_name.lower():
                        if "gasteiz" in long_name.lower() or "ibaiondo" in long_name.lower() or "abetxuko" in long_name.lower():
                            route_op_id = "tranbia_gasteiz"
                            r_territory = "araba"
                            color = "#2FA650"
                        else:
                            route_op_id = "tranbia_bilbao"
                            r_territory = "bizkaia"
                            color = "#2FA650"
                    elif "topo" in long_name.lower() or "donostia" in long_name.lower() or "hendaia" in long_name.lower():
                        r_territory = "gipuzkoa"

                routes_rows.append((
                    scoped_r_id, route_op_id, short_name, long_name,
                    r_type, color, r_territory
                ))

            if routes_rows:
                cur.executemany("INSERT OR REPLACE INTO routes VALUES (?, ?, ?, ?, ?, ?, ?);", routes_rows)

            # 3. Calendar & Calendar Dates
            raw_calendar = parse_csv_from_zip(zf, "calendar.txt")
            cal_rows = []
            valid_service_ids: Set[str] = set()

            for c in raw_calendar:
                raw_s_id = c.get("service_id", "").strip()
                if not raw_s_id:
                    continue
                scoped_s_id = f"{op_id}:{raw_s_id}"
                valid_service_ids.add(scoped_s_id)
                cal_rows.append((
                    scoped_s_id,
                    int(c.get("monday", "0") or 0),
                    int(c.get("tuesday", "0") or 0),
                    int(c.get("wednesday", "0") or 0),
                    int(c.get("thursday", "0") or 0),
                    int(c.get("friday", "0") or 0),
                    int(c.get("saturday", "0") or 0),
                    int(c.get("sunday", "0") or 0),
                    c.get("start_date", "").strip(),
                    c.get("end_date", "").strip()
                ))

            if cal_rows:
                cur.executemany("INSERT OR REPLACE INTO calendar VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", cal_rows)

            raw_cal_dates = parse_csv_from_zip(zf, "calendar_dates.txt")
            cal_date_rows = []
            for cd in raw_cal_dates:
                raw_s_id = cd.get("service_id", "").strip()
                date_str = cd.get("date", "").strip()
                if not raw_s_id or not date_str:
                    continue
                scoped_s_id = f"{op_id}:{raw_s_id}"
                valid_service_ids.add(scoped_s_id)
                try:
                    ex_type = int(cd.get("exception_type", "1").strip())
                except Exception:
                    ex_type = 1
                cal_date_rows.append((scoped_s_id, date_str, ex_type))

            if cal_date_rows:
                cur.executemany("INSERT OR REPLACE INTO calendar_dates VALUES (?, ?, ?);", cal_date_rows)

            # 4. Shapes (compact points_json)
            raw_shapes = parse_csv_from_zip(zf, "shapes.txt")
            shapes_by_id: Dict[str, List[Tuple[int, float, float]]] = {}

            for sh in raw_shapes:
                raw_sh_id = sh.get("shape_id", "").strip()
                if not raw_sh_id:
                    continue
                lat = clean_coord(sh.get("shape_pt_lat", ""))
                lon = clean_coord(sh.get("shape_pt_lon", ""))
                if lat is None or lon is None:
                    continue
                try:
                    seq = int(sh.get("shape_pt_sequence", "0").strip())
                except Exception:
                    seq = 0
                scoped_sh_id = f"{op_id}:{raw_sh_id}"
                shapes_by_id.setdefault(scoped_sh_id, []).append((seq, lon, lat))

            shapes_rows = []
            for sh_id, pts in shapes_by_id.items():
                pts.sort(key=lambda p: p[0])
                coords = [[round(p[1], 5), round(p[2], 5)] for p in pts]
                shapes_rows.append((sh_id, json.dumps(coords, separators=(",", ":"))))

            if shapes_rows:
                cur.executemany("INSERT OR REPLACE INTO shapes VALUES (?, ?);", shapes_rows)

            # 5. Trips
            raw_trips = parse_csv_from_zip(zf, "trips.txt")
            valid_trip_ids: Set[str] = set()
            trips_rows = []

            for t in raw_trips:
                raw_t_id = t.get("trip_id", "").strip()
                raw_r_id = t.get("route_id", "").strip()
                if not raw_t_id or not raw_r_id:
                    continue

                scoped_r_id = f"{op_id}:{raw_r_id}"
                if scoped_r_id not in valid_route_ids:
                    continue

                scoped_t_id = f"{op_id}:{raw_t_id}"
                valid_trip_ids.add(scoped_t_id)

                raw_s_id = t.get("service_id", "").strip()
                scoped_s_id = f"{op_id}:{raw_s_id}" if raw_s_id else "default_service"

                headsign = t.get("trip_headsign", "").strip() or None
                try:
                    dir_id = int(t.get("direction_id", "0").strip())
                except Exception:
                    dir_id = 0

                raw_sh_id = t.get("shape_id", "").strip()
                scoped_sh_id = f"{op_id}:{raw_sh_id}" if raw_sh_id else None

                # Inferred line code for Metro Bilbao and buses
                inferred = None
                if op_id == "metro":
                    h_lower = (headsign or "").lower()
                    if any(s in h_lower for s in ["plentzia", "berango", "larrabasterra", "bidezabal"]):
                        inferred = "L1"
                    elif any(s in h_lower for s in ["kabiezes", "santurtzi"]):
                        inferred = "L2"
                    elif any(s in h_lower for s in ["matiko", "kukullaga"]):
                        inferred = "L3"
                    else:
                        inferred = "L1"

                trips_rows.append((
                    scoped_t_id, scoped_r_id, scoped_s_id,
                    headsign, dir_id, inferred, scoped_sh_id
                ))

            if trips_rows:
                cur.executemany("INSERT OR REPLACE INTO trips VALUES (?, ?, ?, ?, ?, ?, ?);", trips_rows)

            # 6. Stop Times (streamed to avoid high RAM consumption)
            if "stop_times.txt" in zf.namelist():
                with zf.open("stop_times.txt") as st_file:
                    reader = csv.DictReader(io.TextIOWrapper(st_file, encoding="utf-8-sig", errors="replace"))
                    batch = []
                    inserted_st = 0
                    trip_seq_counter: Dict[str, int] = {}

                    for row in reader:
                        raw_t_id = row.get("trip_id", "").strip()
                        raw_s_id = clean_stop_id(row.get("stop_id", ""))
                        if not raw_t_id or not raw_s_id:
                            continue

                        scoped_t_id = f"{op_id}:{raw_t_id}"
                        if scoped_t_id not in valid_trip_ids:
                            continue

                        scoped_s_id = f"{op_id}:{raw_s_id}"
                        if scoped_s_id not in valid_stop_ids:
                            continue

                        raw_seq = row.get("stop_sequence", "").strip()
                        if raw_seq and raw_seq.isdigit():
                            seq = int(raw_seq)
                        else:
                            seq = trip_seq_counter.get(scoped_t_id, 0) + 1
                        trip_seq_counter[scoped_t_id] = seq

                        arr = row.get("arrival_time", "").strip()
                        dep = row.get("departure_time", "").strip() or arr

                        # Clean time format HH:MM:SS
                        if len(arr) == 5:
                            arr = f"{arr}:00"
                        if len(dep) == 5:
                            dep = f"{dep}:00"

                        batch.append((scoped_t_id, scoped_s_id, seq, arr, dep))
                        if len(batch) >= 10000:
                            cur.executemany("INSERT OR IGNORE INTO stop_times VALUES (?, ?, ?, ?, ?);", batch)
                            inserted_st += len(batch)
                            batch = []

                    if batch:
                        cur.executemany("INSERT OR IGNORE INTO stop_times VALUES (?, ?, ?, ?, ?);", batch)
                        inserted_st += len(batch)

                    log(f"  -> Inserted {len(stops_rows)} stops, {len(routes_rows)} routes, {len(trips_rows)} trips, {inserted_st} stop_times for {op_id}.")

        conn.commit()

    except Exception as e:
        log(f"Error processing feed {zip_path} for {op_id}: {e}")
        conn.rollback()

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

    log("Building performance indexes...")
    cur.executescript("""
    CREATE INDEX IF NOT EXISTS idx_stops_bounds ON stops (stop_lat, stop_lon);
    CREATE INDEX IF NOT EXISTS idx_stops_operator ON stops (operator_id);
    CREATE INDEX IF NOT EXISTS idx_stops_parent ON stops (parent_station);
    CREATE INDEX IF NOT EXISTS idx_routes_operator ON routes (operator_id);
    CREATE INDEX IF NOT EXISTS idx_trips_route ON trips (route_id);
    CREATE INDEX IF NOT EXISTS idx_trips_service ON trips (service_id);
    CREATE INDEX IF NOT EXISTS idx_stop_times_stop_dep ON stop_times (stop_id, departure_time);
    CREATE INDEX IF NOT EXISTS idx_calendar_dates_date ON calendar_dates (date);
    """)
    conn.commit()
    log("Running database vacuum & analyze...")
    cur.execute("VACUUM;")
    cur.execute("PRAGMA optimize;")
    conn.commit()
    cur.execute("PRAGMA optimize;")
    conn.commit()

def create_manifest(db_path: str, gz_path: str, manifest_path: str):
    def sha256_file(path: str) -> str:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()

    manifest = {
        "version": "4.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sqlite": {
            "filename": os.path.basename(db_path),
            "bytes": os.path.getsize(db_path),
            "sha256": sha256_file(db_path),
        },
        "compressed": {
            "filename": os.path.basename(gz_path),
            "bytes": os.path.getsize(gz_path),
            "sha256": sha256_file(gz_path),
        },
        "operators": {
            k: {
                "name": v["name"],
                "territory": v["territory"],
                "mode": v["mode"],
                "color": v["color_hex"],
                "has_realtime": bool(v["has_realtime"]),
            }
            for k, v in OPERATOR_CATALOG.items()
        }
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    log(f"Manifest written to {manifest_path}")

def main():
    start_time = time.time()
    out_dir = os.path.join(os.path.dirname(__file__), "out")
    cache_dir = os.path.join(os.path.dirname(__file__), ".cache")
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(cache_dir, exist_ok=True)

    db_path = os.path.join(out_dir, "transit.sqlite")
    gz_path = os.path.join(out_dir, "transit.sqlite.gz")
    manifest_path = os.path.join(out_dir, "manifest.json")

    log("=== Euskadi Multi-Operator GTFS Compiler 4.0 ===")
    feeds = fetch_feed_index()
    downloaded = download_feeds(feeds, cache_dir)

    conn = init_database(db_path)
    try:
        for op_id, op_name, url, zip_path in downloaded:
            process_operator_feed(conn, op_id, zip_path)
        build_indices(conn)
    finally:
        conn.close()

    db_bytes = os.path.getsize(db_path)
    log(f"Database compiled: {db_bytes / (1024*1024):.2f} MB")

    # Compress with Gzip
    log(f"Compressing {db_path} -> {gz_path}...")
    with open(db_path, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        shutil.copyfileobj(f_in, f_out)

    gz_bytes = os.path.getsize(gz_path)
    log(f"Compressed bundle: {gz_bytes / (1024*1024):.2f} MB (saved {(1 - gz_bytes/db_bytes)*100:.1f}%)")

    create_manifest(db_path, gz_path, manifest_path)

    # Copy to assets/db/transit.sqlite
    assets_db = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "db", "transit.sqlite")
    os.makedirs(os.path.dirname(assets_db), exist_ok=True)
    shutil.copyfile(db_path, assets_db)
    log(f"Copied {db_path} to {assets_db}")

    elapsed = time.time() - start_time
    log(f"=== Compilation completed successfully in {elapsed:.2f} seconds ===")

if __name__ == "__main__":
    main()
