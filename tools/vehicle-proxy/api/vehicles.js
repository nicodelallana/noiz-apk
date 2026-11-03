// GET /api/vehicles — live vehicles for the Noiz map, as compact JSON.
//
// Reads the operators' official GTFS-RT VehiclePositions feeds (protobuf),
// labels each vehicle with its line, colour, destination and stop from the
// static GTFS (api/_data/lookups.json, see build_lookups.py) and returns one
// JSON document. Why a proxy at all: none of the feeds sends CORS headers,
// so the web build can't read them; it also turns ~3 protobuf feeds into one
// small response the app polls.
//
// Honesty rules baked in:
//   kind "gps"      real GPS position (Bizkaibus).
//   kind "station"  the train is placed at the last station it was detected
//                   at (Metro Bilbao, Renfe) — not a GPS fix.
//   Positions older than MAX_AGE_S are dropped, never shown as live.
//
// Cached at the CDN for 20 s, so the operators see at most ~3 requests a
// minute whatever the number of users.
//
// Data: Consorcio de Transportes de Bizkaia (CTB), Diputación Foral de
// Bizkaia (Bizkaibus) and Renfe Viajeros — CC BY 4.0.

const { lookups, fetchFeed, num } = require('./_lib/gtfsrt');

const FEEDS = [
  {
    op: 'bizkaibus',
    kind: 'gps',
    url: 'https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedVehiculos.pb',
  },
  {
    op: 'metro',
    kind: 'station',
    url: 'https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-vehicle-positions.pb',
  },
  {
    op: 'renfe',
    kind: 'station',
    url: 'https://gtfsrt.renfe.com/vehicle_positions.pb',
  },
];

const MAX_AGE_S = 180;
const STATUS = ['incoming', 'stopped', 'in_transit'];
// Bizkaia, roughly: Renfe's feed is national.
const inBizkaia = (lat, lon) => lat > 42.9 && lat < 43.5 && lon > -3.45 && lon < -2.4;

// Line, colour, destination and stop name for one vehicle, per operator.
const label = {
  metro(v) {
    const L = lookups.metro;
    const [line, headsign] = L.trips[v.trip?.tripId] || [null, null];
    const stopId = v.stopId || '';
    return {
      line: line || 'Metro',
      color: L.lines[line] || 'FF6505',
      headsign,
      // Feed uses platform ids ("10.0") for station "10".
      stop: L.stops[stopId] || L.stops[stopId.split('.')[0]] || null,
    };
  },
  bizkaibus(v) {
    const L = lookups.bizkaibus;
    const trip = L.trips[v.trip?.tripId];
    const route = trip ? L.routes[trip[0]] : null;
    return {
      line: route ? route[0] : 'Bizkaibus',
      color: route ? route[1] : '2E9E4F',
      headsign: trip ? L.headsigns[trip[1]] || null : null,
      stop: L.stops[v.stopId] || null,
    };
  },
  renfe(v, lat, lon) {
    const L = lookups.renfe;
    const routeId = L.trips[v.trip?.tripId];
    const route = routeId ? L.routes[routeId] : null;
    if (!route && !inBizkaia(lat, lon)) return null; // another city
    // Fallback for trips missing from the static file: "C1-23515-PLATF.(1)".
    const fromLabel = (v.vehicle?.label || '').split('-')[0];
    return {
      line: route ? route[0] : fromLabel || 'Cercanías',
      color: route ? route[1] : 'D7001E',
      headsign: route ? route[2] : null,
      stop: L.stops[v.stopId] || null,
    };
  },
};

async function collect(feed, now) {
  const msg = await fetchFeed(feed.url);
  const headerTs = num(msg.header?.timestamp);
  const out = [];
  for (const e of msg.entity) {
    const v = e.vehicle;
    const lat = v?.position?.latitude;
    const lon = v?.position?.longitude;
    if (!lat || !lon) continue;
    if (feed.op !== 'renfe' && !inBizkaia(lat, lon)) continue;
    const ts = num(v.timestamp) || headerTs;
    if (!ts || now - ts > MAX_AGE_S) continue;
    const l = label[feed.op](v, lat, lon);
    if (!l) continue;
    out.push({
      id: `${feed.op}:${v.vehicle?.id || e.id}`,
      op: feed.op,
      kind: feed.kind,
      lat: Math.round(lat * 1e5) / 1e5,
      lon: Math.round(lon * 1e5) / 1e5,
      bearing: v.position.bearing ? Math.round(v.position.bearing) : null,
      line: l.line,
      color: `#${l.color}`,
      headsign: l.headsign,
      stop: l.stop,
      status: v.currentStatus != null ? STATUS[v.currentStatus] || null : null,
      ts,
    });
  }
  return { vehicles: out, headerTs };
}

module.exports = async (req, res) => {
  const now = Math.floor(Date.now() / 1000);
  const results = await Promise.allSettled(FEEDS.map((f) => collect(f, now)));

  const vehicles = [];
  const sources = FEEDS.map((f, i) => {
    const r = results[i];
    if (r.status === 'fulfilled') {
      vehicles.push(...r.value.vehicles);
      return { op: f.op, kind: f.kind, ok: true, count: r.value.vehicles.length, feedTs: r.value.headerTs };
    }
    return { op: f.op, kind: f.kind, ok: false, count: 0, error: String(r.reason?.message || r.reason) };
  });

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=10, s-maxage=20, stale-while-revalidate=40');
  res.statusCode = 200;
  res.end(JSON.stringify({
    generatedAt: now,
    attribution: 'Datos en directo: CTB · Diputación Foral de Bizkaia · Renfe (CC BY 4.0)',
    sources,
    vehicles,
  }));
};
