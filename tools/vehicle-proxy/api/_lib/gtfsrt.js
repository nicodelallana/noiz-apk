// Shared helpers for the proxy endpoints (files under api/_lib are not
// routes on Vercel). Feeds are official GTFS-RT (protobuf), CC BY 4.0.

const GtfsRealtimeBindings = require('gtfs-realtime-bindings');
const lookups = require('../_data/lookups.json');

const TIMEOUT_MS = 8000;
const ATTRIBUTION =
  'Datos en directo: CTB · Metro Bilbao · Euskotren · Diputación Foral de Bizkaia · Renfe (CC BY 4.0)';

const num = (v) => (v == null ? null : Number(v));

async function fetchFeed(url) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, { signal: ctrl.signal });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const buf = new Uint8Array(await res.arrayBuffer());
    return GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(buf);
  } finally {
    clearTimeout(timer);
  }
}

/** Spanish text of a TranslatedString (feeds carry es + eu). */
function text(ts) {
  const tr = ts?.translation || [];
  const es = tr.find((t) => ['es', 'es-ES', ''].includes(t.language || ''));
  return ((es || tr[0])?.text || '').trim();
}

/** Metres between two points (equirectangular is plenty at city scale). */
function metres(lat1, lon1, lat2, lon2) {
  const x = ((lon2 - lon1) * Math.PI) / 180 * Math.cos(((lat1 + lat2) / 2) * Math.PI / 180);
  const y = ((lat2 - lat1) * Math.PI) / 180;
  return Math.sqrt(x * x + y * y) * 6371000;
}

/** Official stop ids of one operator within [radius] metres of a point. */
function stopsNear(op, lat, lon, radius) {
  const coords = lookups[op]?.coords || {};
  const out = [];
  for (const [id, [la, lo]] of Object.entries(coords)) {
    const d = metres(lat, lon, la, lo);
    if (d <= radius) out.push({ id, d });
  }
  return out.sort((a, b) => a.d - b.d);
}

function send(res, body, sMaxAge) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader(
    'Cache-Control',
    `public, max-age=10, s-maxage=${sMaxAge}, stale-while-revalidate=${sMaxAge * 2}`,
  );
  res.statusCode = 200;
  res.end(JSON.stringify(body));
}

module.exports = { lookups, fetchFeed, text, metres, stopsNear, send, num, ATTRIBUTION };
