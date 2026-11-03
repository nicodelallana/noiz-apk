// GET /api/alerts — official service incidents in force now (GTFS-RT
// Alerts) for Metro Bilbao, Bizkaibus, Euskotren and Renfe Cercanías Bilbao,
// with the affected lines and stops (named and located, for "Cerca de ti").
//
// Clean-up the feeds need:
//   Bizkaibus titles every alert "Incidencia"; the real title is the first
//   clause of the description ("TRASLADO PARADA EN BERMEO: …").
//   Identical texts repeated once per line are merged.
//   Metro marks almost every station as affected; when an alert names one
//   station in its text, that station is used, else it is network-wide.
//   Renfe's feed is national (filtered to Bilbao) and is skipped when stale.

const { lookups, fetchFeed, text, send, num, ATTRIBUTION } = require('./_lib/gtfsrt');

const FEEDS = [
  { op: 'metro', url: 'https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-service-alerts.pb' },
  { op: 'bizkaibus', url: 'https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedAlerts.pb' },
  {
    op: 'euskotren',
    url: 'https://opendata.euskadi.eus/transport/moveuskadi/euskotren/gtfsrt_euskotren_alerts.pb',
  },
  { op: 'renfe', url: 'https://gtfsrt.renfe.com/alerts.pb' },
];
const STALE_AFTER_S = 6 * 3600;
const MAX_STOPS = 8;
const SMALL = new Set(['de', 'del', 'la', 'las', 'el', 'los', 'y', 'a', 'en', 'e', 'o', 'al', 'por', 'con']);
// GTFS-RT Alert.Effect → app severity.
const SEVERITY = { 1: 'severe', 2: 'warning', 3: 'warning', 4: 'warning', 6: 'warning', 5: 'info', 7: 'info', 8: 'info', 9: 'info', 10: 'info', 11: 'info' };

/** "TRASLADO PARADA EN BERMEO" → "Traslado parada en Bermeo"-ish: shouty
 *  feeds become title case (small words lower); mixed case is kept. */
function tidy(s) {
  s = (s || '').replace(/\s+/g, ' ').replace(/:(?=\S)/g, ': ').trim();
  if (!s || s !== s.toUpperCase()) return s;
  return s
    .toLowerCase()
    .split(' ')
    .map((w, i) => (i && SMALL.has(w) ? w : w.charAt(0).toUpperCase() + w.slice(1)))
    .join(' ');
}

function lineOf(op, routeId) {
  if (op === 'metro') return { name: 'Metro', color: '#FF6505' };
  const r = lookups[op]?.routes?.[routeId];
  return r ? { name: r[0], color: `#${r[1]}` } : null;
}

function stopOf(op, stopId) {
  const L = lookups[op];
  const id = L.coords[stopId] ? stopId : String(stopId).split('.')[0];
  const c = L.coords[id];
  const name = L.stops[id] || L.stops[stopId];
  return c && name ? { name, lat: c[0], lon: c[1] } : null;
}

function activeNow(alert, now) {
  const periods = alert.activePeriod || [];
  if (!periods.length) return true;
  return periods.some((p) => {
    const start = num(p.start) || 0;
    const end = num(p.end) || Infinity;
    return start <= now && now <= end;
  });
}

async function collect(feed, now) {
  const msg = await fetchFeed(feed.url);
  const headerTs = num(msg.header?.timestamp);
  if (headerTs && now - headerTs > STALE_AFTER_S) return { stale: true, headerTs, alerts: [] };

  const merged = new Map();
  for (const e of msg.entity) {
    const a = e.alert;
    if (!a || !activeNow(a, now)) continue;
    const entities = a.informedEntity || [];
    if (feed.op === 'renfe') {
      const bilbao = entities.some(
        (ie) => (ie.routeId || '').startsWith('60T') || lookups.renfe.coords[ie.stopId],
      );
      if (!bilbao) continue;
    }

    let title = text(a.headerText);
    let body = text(a.descriptionText);
    if ((!title || /^incidencia$/i.test(title)) && body.includes(':')) {
      const i = body.indexOf(':');
      title = body.slice(0, i);
      body = body.slice(i + 1);
    }
    title = tidy(title) || 'Incidencia';
    body = tidy(body);

    const key = `${feed.op}|${title}|${body}`;
    const item = merged.get(key) || {
      id: `${feed.op}:${e.id}`,
      op: feed.op,
      title,
      body,
      severity: SEVERITY[a.effect] || 'info',
      from: num(a.activePeriod?.[0]?.start) || null,
      to: num(a.activePeriod?.[0]?.end) || null,
      lines: [],
      stops: [],
    };
    for (const ie of entities) {
      const line = ie.routeId ? lineOf(feed.op, ie.routeId) : null;
      if (line && !item.lines.some((l) => l.name === line.name)) item.lines.push(line);
      const stop = ie.stopId ? stopOf(feed.op, ie.stopId) : null;
      if (stop && !item.stops.some((s) => s.name === stop.name)) item.stops.push(stop);
    }
    merged.set(key, item);
  }

  const alerts = [...merged.values()].map((a) => {
    if (a.stops.length <= MAX_STOPS) return { ...a, networkWide: false };
    // Too many stops to be specific: use the one named in the text, if any.
    const hay = `${a.title} ${a.body}`.toLowerCase();
    const named = a.stops.filter((s) => s.name.length > 3 && hay.includes(s.name.toLowerCase()));
    return named.length === 1
      ? { ...a, stops: named, networkWide: false }
      : { ...a, stops: [], networkWide: true };
  });
  return { stale: false, headerTs, alerts };
}

module.exports = async (req, res) => {
  const now = Math.floor(Date.now() / 1000);
  const results = await Promise.allSettled(FEEDS.map((f) => collect(f, now)));
  const alerts = [];
  const sources = FEEDS.map((f, i) => {
    const r = results[i];
    if (r.status === 'rejected') {
      return { op: f.op, ok: false, count: 0, error: String(r.reason?.message || r.reason) };
    }
    alerts.push(...r.value.alerts);
    return { op: f.op, ok: true, stale: r.value.stale, count: r.value.alerts.length, feedTs: r.value.headerTs };
  });
  const rank = { severe: 0, warning: 1, info: 2 };
  alerts.sort((a, b) => rank[a.severity] - rank[b.severity]);
  send(res, { generatedAt: now, attribution: ATTRIBUTION, sources, alerts }, 60);
};
