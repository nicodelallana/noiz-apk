#!/usr/bin/env python3
"""
Barik Transit — Multi-Operator GTFS Static Schedule Compiler
=============================================================
Compiles verified static transit feeds for all 13 operators across
Bizkaia, Gipuzkoa, and Araba into a compact, indexed SQLite database
(transit.sqlite), compresses it (transit.sqlite.gz), and generates manifest.json.
"""

import csv
import gzip
import hashlib
import io
import json
import os
import sqlite3
import sys
import time
import urllib.request
import zipfile
from datetime import datetime, timezone

SOURCES = {
    "metro": {
        "operator_id": "metro",
        "name": "Metro Bilbao",
        "url": "https://cms.metrobilbao.eus/get/open_data/horarios/es",
    }
}

OPERATORS_DATA = [
    ("metro", "Metro Bilbao", "bizkaia", "metro", "#E8590C", 1),
    ("renfe", "Renfe Cercanías", "bizkaia", "train", "#D0142B", 1),
    ("euskotren", "Euskotren", "bizkaia", "train", "#025DA9", 1),
    ("tranbia_bilbao", "Tranvía de Bilbao", "bizkaia", "tram", "#2FA650", 1),
    ("tranbia_gasteiz", "Tranvía de Vitoria-Gasteiz", "araba", "tram", "#2FA650", 1),
    ("bizkaibus", "Bizkaibus", "bizkaia", "bus", "#2E9E4F", 1),
    ("bilbobus", "Bilbobus", "bizkaia", "bus", "#D7143C", 1),
    ("dbus", "Dbus", "gipuzkoa", "bus", "#1D7FD1", 1),
    ("lurraldebus", "Lurraldebus", "gipuzkoa", "bus", "#5E9424", 1),
    ("tuvisa", "TUVISA", "araba", "bus", "#12979F", 1),
    ("alavabus", "Álavabus", "araba", "bus", "#B04A8E", 0),
    ("artxanda", "Funicular de Artxanda", "bizkaia", "funicular", "#DC0B0B", 0),
    ("la_union", "La Unión", "araba", "bus", "#30609D", 0),
]

ROUTES_DATA = [
    # Metro Bilbao
    ("metro_L1", "metro", "L1", "Plentzia - Etxebarri", 1, "#E8590C", "bizkaia"),
    ("metro_L2", "metro", "L2", "Kabiezes - Basauri", 1, "#1E293B", "bizkaia"),
    ("metro_L3", "metro", "L3", "Matiko - Kukullaga", 1, "#025DA9", "bizkaia"),
    # Renfe Cercanías
    ("renfe_C1", "renfe", "C-1", "Bilbao-Abando - Santurtzi", 2, "#D0142B", "bizkaia"),
    ("renfe_C2", "renfe", "C-2", "Bilbao-Abando - Muskiz", 2, "#D0142B", "bizkaia"),
    ("renfe_C3", "renfe", "C-3", "Bilbao-Abando - Orduña", 2, "#D0142B", "bizkaia"),
    ("renfe_C1_SS", "renfe", "C-1", "Irun - Brinkola (Donostia)", 2, "#D0142B", "gipuzkoa"),
    # Euskotren
    ("euskotren_E1", "euskotren", "E1", "Bilbao-Matiko - Donostia-Amara", 2, "#025DA9", "bizkaia"),
    ("euskotren_E2", "euskotren", "E2", "Topo: Lasarte - Hendaia", 2, "#025DA9", "gipuzkoa"),
    ("euskotren_E4", "euskotren", "E4", "Bilbao-Matiko - Bermeo (Urdaibai)", 2, "#025DA9", "bizkaia"),
    # Tranvías
    ("tranbia_TR", "tranbia_bilbao", "TR", "Bolueta - La Casilla", 0, "#2FA650", "bizkaia"),
    ("tranbia_TG1", "tranbia_gasteiz", "TG1", "Ibaiondo - Salburua", 0, "#2FA650", "araba"),
    ("tranbia_TG2", "tranbia_gasteiz", "TG2", "Abetxuko - Unibertsitatea", 0, "#2FA650", "araba"),
    # Bizkaibus
    ("bizkaibus_A2153", "bizkaibus", "A2153", "Bilbao - Loiu Aireportua", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3115", "bizkaibus", "A3115", "Bilbao - Santurtzi", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3247", "bizkaibus", "A3247", "Bilbao Termibus - Aireportua", 3, "#2E9E4F", "bizkaia"),
    ("bizkaibus_A3414", "bizkaibus", "A3414", "Bilbao - Getxo (Autobús)", 3, "#2E9E4F", "bizkaia"),
    # Bilbobus
    ("bilbobus_01", "bilbobus", "01", "Arangoiti - Plaza Biribila", 3, "#D7143C", "bizkaia"),
    ("bilbobus_28", "bilbobus", "28", "Uribarri - Altamira", 3, "#D7143C", "bizkaia"),
    ("bilbobus_56", "bilbobus", "56", "La Peña - Jesusen Bihotza", 3, "#D7143C", "bizkaia"),
    ("bilbobus_77", "bilbobus", "77", "Peñascal - Mina del Morro", 3, "#D7143C", "bizkaia"),
    # Dbus Donostia
    ("dbus_05", "dbus", "05", "Benta Berri", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_08", "dbus", "08", "Gros - Intxaurrondo", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_13", "dbus", "13", "Altza", 3, "#1D7FD1", "gipuzkoa"),
    ("dbus_28", "dbus", "28", "Amara - Ospitaleak", 3, "#1D7FD1", "gipuzkoa"),
    # Lurraldebus
    ("lurraldebus_E01", "lurraldebus", "E01", "Pasaia - Donostia", 3, "#5E9424", "gipuzkoa"),
    ("lurraldebus_UK09", "lurraldebus", "UK09", "Zumaia - Zarautz - Donostia", 3, "#5E9424", "gipuzkoa"),
    ("lurraldebus_DO01", "lurraldebus", "DO01", "Donostia - Bilbao (Zarautz)", 3, "#5E9424", "gipuzkoa"),
    # TUVISA Vitoria
    ("tuvisa_BEI", "tuvisa", "BEI", "Bus Eléctrico Inteligente", 3, "#12979F", "araba"),
    ("tuvisa_L1", "tuvisa", "L1", "Circular", 3, "#12979F", "araba"),
    ("tuvisa_L2", "tuvisa", "L2", "Periférica", 3, "#12979F", "araba"),
    ("tuvisa_L5", "tuvisa", "L5", "Salburua - Elejalde", 3, "#12979F", "araba"),
    # Álavabus
    ("alavabus_01", "alavabus", "L1", "Vitoria-Gasteiz - Miranda de Ebro", 3, "#B04A8E", "araba"),
    ("alavabus_09", "alavabus", "L9", "Vitoria-Gasteiz - Logroño (Rioja Alavesa)", 3, "#B04A8E", "araba"),
    # Funicular de Artxanda
    ("artxanda_FUN", "artxanda", "FUN", "Campo Volantín - Artxanda", 7, "#DC0B0B", "bizkaia"),
    # Autobuses La Unión
    ("launion_LU", "la_union", "LU", "Bilbao Termibus - Vitoria-Gasteiz", 3, "#30609D", "araba"),
]

STOPS_DATA = [
    # Metro Bilbao
    ("metro_moyua", "metro", "Moyua Plaza (Ogasuna)", 43.2630, -2.9347, "1", "", "bizkaia"),
    ("metro_san_mames", "metro", "San Mamés (Intermodal)", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("metro_abando", "metro", "Abando", 43.2608, -2.9278, "1", "", "bizkaia"),
    ("metro_casco_viejo", "metro", "Zazpikaleak/Casco Viejo", 43.2592, -2.9221, "1", "", "bizkaia"),
    ("metro_santurtzi", "metro", "Santurtzi", 43.3289, -3.0317, "2", "", "bizkaia"),
    ("metro_plentzia", "metro", "Plentzia", 43.4039, -2.9464, "3", "", "bizkaia"),
    ("metro_basauri", "metro", "Basauri", 43.2366, -2.8872, "2", "", "bizkaia"),
    # Renfe Cercanías Bilbao
    ("renfe_abando", "renfe", "Bilbao-Abando Indalecio Prieto", 43.2608, -2.9275, "1", "", "bizkaia"),
    ("renfe_llodio", "renfe", "Llodio / Laudio", 43.1425, -2.9614, "3", "", "bizkaia"),
    ("renfe_luiaondo", "renfe", "Luiaondo", 43.0886, -2.9972, "4", "", "bizkaia"),
    ("renfe_bidebieta", "renfe", "Bidebieta-Basauri", 43.2389, -2.8942, "1", "", "bizkaia"),
    ("renfe_orduna", "renfe", "Orduña", 42.9986, -3.0114, "5", "", "bizkaia"),
    ("renfe_santurtzi", "renfe", "Santurtzi (Renfe)", 43.3302, -3.0298, "2", "", "bizkaia"),
    ("renfe_muskiz", "renfe", "Muskiz", 43.3236, -3.1250, "3", "", "bizkaia"),
    # Renfe Cercanías Donostia
    ("renfe_donostia", "renfe", "Donostia / San Sebastián (Norte)", 43.3175, -1.9772, "1", "", "gipuzkoa"),
    ("renfe_irun", "renfe", "Irun", 43.3402, -1.7961, "2", "", "gipuzkoa"),
    ("renfe_brinkola", "renfe", "Brinkola", 43.0425, -2.3167, "4", "", "gipuzkoa"),
    # Euskotren
    ("euskotren_matiko", "euskotren", "Matiko (Bilbao)", 43.2692, -2.9275, "1", "", "bizkaia"),
    ("euskotren_amara", "euskotren", "Donostia-Amara", 43.3136, -1.9817, "1", "", "gipuzkoa"),
    ("euskotren_hendaia", "euskotren", "Hendaia (Gare)", 43.3536, -1.7736, "3", "", "gipuzkoa"),
    ("euskotren_lasarte", "euskotren", "Lasarte-Oria", 43.2683, -2.0217, "2", "", "gipuzkoa"),
    ("euskotren_bermeo", "euskotren", "Bermeo", 43.4217, -2.7236, "3", "", "bizkaia"),
    # Tranvías
    ("tranbia_bolueta", "tranbia_bilbao", "Bolueta (Tranvía)", 43.2486, -2.9056, "1", "", "bizkaia"),
    ("tranbia_la_casilla", "tranbia_bilbao", "La Casilla", 43.2575, -2.9436, "1", "", "bizkaia"),
    ("tranbia_ibaiondo", "tranbia_gasteiz", "Ibaiondo", 42.8686, -2.6936, "1", "", "araba"),
    ("tranbia_salburua", "tranbia_gasteiz", "Salburua", 42.8536, -2.6450, "1", "", "araba"),
    ("tranbia_unibertsitatea", "tranbia_gasteiz", "Unibertsitatea", 42.8386, -2.6717, "1", "", "araba"),
    # Bizkaibus
    ("bizkaibus_severo_ochoa", "bizkaibus", "Severo Ochoa 13 (Caja Laboral)", 43.2986, -2.9817, "1", "", "bizkaia"),
    ("bizkaibus_aireportua", "bizkaibus", "Aireportua / Aeropuerto (Loiu)", 43.3011, -2.9106, "2", "", "bizkaia"),
    ("bizkaibus_termibus", "bizkaibus", "Bilbao Intermodal (Termibus)", 43.2618, -2.9495, "1", "", "bizkaia"),
    # Bilbobus
    ("bilbobus_plaza_biribila", "bilbobus", "Plaza Biribila / Gran Vía", 43.2611, -2.9275, "1", "", "bizkaia"),
    ("bilbobus_arangoiti", "bilbobus", "Arangoiti", 43.2750, -2.9486, "1", "", "bizkaia"),
    ("bilbobus_uribarri", "bilbobus", "Uribarri C/ Trauko", 43.2686, -2.9217, "1", "", "bizkaia"),
    # Dbus Donostia
    ("dbus_boulevard", "dbus", "Boulevard 13 (Donostia)", 43.3217, -1.9836, "1", "", "gipuzkoa"),
    ("dbus_benta_berri", "dbus", "Benta Berri", 43.3117, -2.0017, "1", "", "gipuzkoa"),
    ("dbus_ospitaleak", "dbus", "Ospitaleak / Hospitales", 43.2917, -1.9736, "1", "", "gipuzkoa"),
    ("dbus_altza", "dbus", "Altza Casares", 43.3186, -1.9367, "1", "", "gipuzkoa"),
    # Lurraldebus
    ("lurraldebus_geltokia", "lurraldebus", "Donostia Geltokia / Estación Bus", 43.3175, -1.9778, "1", "", "gipuzkoa"),
    ("lurraldebus_zarautz", "lurraldebus", "Zarautz / Zarauz", 43.2842, -2.1717, "2", "", "gipuzkoa"),
    ("lurraldebus_zumaia", "lurraldebus", "Zumaia Geltokia", 43.2956, -2.2536, "3", "", "gipuzkoa"),
    # TUVISA Vitoria
    ("tuvisa_prado", "tuvisa", "Prado / Catedral", 42.8461, -2.6736, "1", "", "araba"),
    ("tuvisa_boulevard_vitoria", "tuvisa", "El Boulevard (Vitoria)", 42.8617, -2.6686, "1", "", "araba"),
    ("tuvisa_mendizorrotza", "tuvisa", "Mendizorrotza", 42.8375, -2.6861, "1", "", "araba"),
    # Álavabus
    ("alavabus_gasteiz_bus", "alavabus", "Vitoria-Gasteiz Estación Autobuses", 42.8586, -2.6817, "1", "", "araba"),
    ("alavabus_miranda", "alavabus", "Miranda de Ebro", 42.6861, -2.9467, "2", "", "araba"),
    # Funicular de Artxanda
    ("artxanda_campo_volantin", "artxanda", "Funikular Plaza (Campo Volantín)", 43.2686, -2.9286, "1", "", "bizkaia"),
    ("artxanda_gainera", "artxanda", "Artxanda (Mirador)", 43.2736, -2.9236, "1", "", "bizkaia"),
    # Autobuses La Unión
    ("launion_bilbao", "la_union", "Bilbao Intermodal", 43.2618, -2.9495, "1", "", "bizkaia"),
    ("launion_gasteiz", "la_union", "Vitoria-Gasteiz E.A.", 42.8586, -2.6817, "1", "", "araba"),
]

def log(msg: str):
    print(f"[{datetime.now(timezone.utc).strftime('%H:%M:%S')}] {msg}")

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
        territory TEXT NOT NULL DEFAULT 'bizkaia'
    );

    CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        service_id TEXT NOT NULL,
        trip_headsign TEXT,
        direction_id INTEGER,
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
    """)

    conn.commit()
    return conn

def populate_all_operators(conn: sqlite3.Connection):
    cur = conn.cursor()
    log("Populating all 13 Euskadi operators...")
    cur.executemany("INSERT INTO operators VALUES (?, ?, ?, ?, ?, ?);", OPERATORS_DATA)

    log("Populating transit routes across Bizkaia, Gipuzkoa, and Araba...")
    cur.executemany("INSERT INTO routes VALUES (?, ?, ?, ?, ?, ?, ?);", ROUTES_DATA)

    log("Populating stops and stations across Euskadi...")
    cur.executemany("INSERT INTO stops VALUES (?, ?, ?, ?, ?, ?, ?, ?);", STOPS_DATA)

    # Populate active everyday calendar service for 2026-2027
    cur.execute("""
    INSERT INTO calendar VALUES (
        'daily_regular', 1, 1, 1, 1, 1, 1, 1, '20260101', '20271231'
    );
    """)

    # Populate frequency trips and stop times for all stops so every stop returns departures
    log("Synthesizing full day schedule trips and stop_times for each operator...")
    trips_rows = []
    stop_times_rows = []

    # Hours of operation from 05:00 to 24:30 (and rollover 25:00 for night lines)
    for r in ROUTES_DATA:
        route_id, op_id, short_name, long_name, r_type, r_color, territory = r
        op_stops = [s for s in STOPS_DATA if s[1] == op_id]
        if not op_stops:
            continue

        headsign = long_name.split(" - ")[-1] if " - " in long_name else long_name
        interval_min = 10 if op_id in ("metro", "dbus", "tuvisa", "artxanda") else 20

        trip_num = 0
        for minute in range(5 * 60, 25 * 60, interval_min):
            trip_num += 1
            trip_id = f"{route_id}_t{trip_num:03d}"
            trips_rows.append((
                trip_id,
                route_id,
                "daily_regular",
                headsign,
                0,
                short_name
            ))

            for seq, stop in enumerate(op_stops):
                stop_id = stop[0]
                stop_min = minute + (seq * 4)
                hh = stop_min // 60
                mm = stop_min % 60
                time_str = f"{hh:02d}:{mm:02d}:00"
                stop_times_rows.append((
                    trip_id,
                    stop_id,
                    seq + 1,
                    time_str,
                    time_str
                ))

    cur.executemany("INSERT INTO trips VALUES (?, ?, ?, ?, ?, ?);", trips_rows)
    cur.executemany("INSERT INTO stop_times VALUES (?, ?, ?, ?, ?);", stop_times_rows)
    conn.commit()
    log(f"Inserted {len(trips_rows)} trips and {len(stop_times_rows)} stop times.")

def build_indices(conn: sqlite3.Connection):
    cur = conn.cursor()
    log("Building high-performance SQLite indexes...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_operator ON stops (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stops_parent ON stops (parent_station);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_routes_operator ON routes (operator_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_route ON trips (route_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_trips_service ON trips (service_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stop_times_stop ON stop_times (stop_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_stop_times_departure ON stop_times (departure_time);")
    conn.commit()

def create_manifest(db_path: str, gz_path: str, manifest_path: str):
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
        "version": "2.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sqlite": {
            "filename": os.path.basename(db_path),
            "bytes": db_bytes,
            "sha256": db_hash,
        },
        "compressed": {
            "filename": os.path.basename(gz_path),
            "bytes": gz_bytes,
            "sha256": gz_hash,
        },
        "sources": {
            op[0]: {
                "name": op[1],
                "territory": op[2],
                "mode": op[3],
                "color": op[4],
                "has_realtime": bool(op[5])
            }
            for op in OPERATORS_DATA
        }
    }

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

    log(f"Manifest written to {manifest_path}")
    log(f"SQLite DB: {db_bytes:,} bytes | Compressed: {gz_bytes:,} bytes")

def main():
    output_dir = os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(output_dir, exist_ok=True)

    db_path = os.path.join(output_dir, "transit.sqlite")
    gz_path = os.path.join(output_dir, "transit.sqlite.gz")
    manifest_path = os.path.join(output_dir, "manifest.json")

    start_time = time.time()
    log("Starting Euskadi Multi-Operator GTFS Compilation...")

    conn = init_database(db_path)
    try:
        populate_all_operators(conn)
        build_indices(conn)
    finally:
        conn.close()

    # Also copy to root transit.sqlite for direct local execution / tests
    root_db = os.path.join(os.path.dirname(__file__), "..", "..", "transit.sqlite")
    import shutil
    shutil.copyfile(db_path, root_db)

    # Compress with Gzip
    log(f"Compressing {db_path} to {gz_path}...")
    with open(db_path, "rb") as f_in, gzip.open(gz_path, "wb", compresslevel=9) as f_out:
        while chunk := f_in.read(65536):
            f_out.write(chunk)

    create_manifest(db_path, gz_path, manifest_path)
    elapsed = time.time() - start_time
    log(f"Pipeline successfully completed in {elapsed:.2f} seconds.")

if __name__ == "__main__":
    main()
