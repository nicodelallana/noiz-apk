"""Builds api/_data/lookups.json: the static GTFS facts the vehicle proxy
needs to label a live vehicle (line, colour, destination, stop name).

GTFS-RT vehicle positions only carry ids (trip_id, stop_id); names and
colours live in each operator's official static GTFS. Run this whenever an
operator publishes a new static GTFS (Bizkaibus: every ~2 months).

Usage: python3 build_lookups.py <dir with gtfs_metro/ gtfs_bzk/ gtfs_renfe/>

Sources (official, CC BY 4.0):
  gtfs_metro  https://ctb-gtfs.s3.eu-south-2.amazonaws.com/metrobilbao.zip
  gtfs_bzk    https://ctb-gtfs.s3.eu-south-2.amazonaws.com/bizkaibus.zip
  gtfs_renfe  https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip
Only routes.txt, trips.txt and stops.txt are read.
"""
import csv
import json
import os
import re
import sys

SMALL = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'a', 'en', 'e', 'o'}


def nice(name):
    """'SANTA ANA 2 (2)' -> 'Santa Ana 2'; keeps mixed-case names. The
    trailing "(806)" is the operator's internal stop code, not a name."""
    name = re.sub(r'\s*\(\d+\)$', '', ' '.join(name.split()))
    if name != name.upper():
        return name
    words = ['/'.join(p.capitalize() for p in w.split('/'))
             for w in name.lower().split(' ')]
    return ' '.join(w.lower() if i and w.lower() in SMALL else w
                    for i, w in enumerate(words))


def rows(path):
    with open(path, encoding='utf-8-sig') as fh:
        for r in csv.DictReader(fh):
            yield {k.strip(): (v or '').strip() for k, v in r.items() if k}


def metro(d):
    # One GTFS route ("MB") for both lines; the shape tells them apart:
    # Kabiezes/Basauri (KAB/BSR) is L2, everything else L1.
    trips = {}
    for t in rows(f'{d}/trips.txt'):
        shape = t.get('shape_id', '')
        line = 'L2' if 'KAB' in shape or 'BSR' in shape else 'L1'
        trips[t['trip_id']] = [line, nice(t.get('trip_headsign', ''))]
    stops = {s['stop_id']: nice(s['stop_name']) for s in rows(f'{d}/stops.txt')}
    return {
        'name': 'Metro Bilbao',
        'lines': {'L1': 'FF6505', 'L2': 'D94A00'},
        'trips': trips,
        'stops': stops,
    }


def bizkaibus(d):
    routes = {r['route_id']: [r['route_short_name'], r.get('route_color') or '2E9E4F']
              for r in rows(f'{d}/routes.txt')}
    heads, head_ix, trips = [], {}, {}
    for t in rows(f'{d}/trips.txt'):
        h = nice(t.get('trip_headsign', ''))
        if h not in head_ix:
            head_ix[h] = len(heads)
            heads.append(h)
        trips[t['trip_id']] = [t['route_id'], head_ix[h]]
    stops = {s['stop_id']: nice(s['stop_name']) for s in rows(f'{d}/stops.txt')}
    return {'name': 'Bizkaibus', 'routes': routes, 'headsigns': heads,
            'trips': trips, 'stops': stops}


def renfe(d):
    # National file: keep the Bilbao commuter network (route ids "60T…").
    routes = {}
    for r in rows(f'{d}/routes.txt'):
        if r['route_id'].startswith('60T'):
            dest = r.get('route_long_name', '').split('-')[-1]
            routes[r['route_id']] = [r['route_short_name'], r.get('route_color') or 'D7001E', nice(dest)]
    trips = {t['trip_id']: t['route_id'] for t in rows(f'{d}/trips.txt')
             if t['route_id'] in routes}
    stops = {}
    for s in rows(f'{d}/stops.txt'):
        lat, lon = float(s['stop_lat']), float(s['stop_lon'])
        if 42.9 < lat < 43.45 and -3.35 < lon < -2.55:
            stops[s['stop_id']] = nice(s['stop_name'])
    return {'name': 'Renfe Cercanías', 'routes': routes, 'trips': trips, 'stops': stops}


def main():
    src = sys.argv[1]
    out = {
        'metro': metro(f'{src}/gtfs_metro'),
        'bizkaibus': bizkaibus(f'{src}/gtfs_bzk'),
        'renfe': renfe(f'{src}/gtfs_renfe'),
    }
    path = os.path.join(os.path.dirname(__file__), 'api', '_data', 'lookups.json')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(',', ':'))
    for k, v in out.items():
        print(k, 'trips', len(v['trips']), 'stops', len(v['stops']))
    print(path, os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    main()
