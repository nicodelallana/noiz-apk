// GET /api/departures?op=metro|euskotren&lat=…&lon=…
//
// Next departures from the official stops of one operator around a point,
// from its GTFS-RT TripUpdates. The app sends its stop's coordinates (its
// own stop ids are not the operators' ones).
//
// Honesty rules:
//   Metro Bilbao  the feed only carries running trains with predicted
//                 times → every departure is realtime.
//   Euskotren     the feed also lists trains that haven't left yet with
//                 their timetable times → realtime only if the train has
//                 started or the stop carries an explicit delay; otherwise
//                 it is the official timetable ("Según horario").
//   Renfe         its feed gives only each train's next stop, not enough
//                 for a station's list → not served here (yet).
// Cancelled trips/stops are returned flagged, never silently dropped.

const { lookups, fetchFeed, stopsNear, send, num, ATTRIBUTION } = require('./_lib/gtfsrt');

const FEEDS = {
  metro: 'https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-trip-updates.pb',
  euskotren:
    'https://opendata.euskadi.eus/transport/moveuskadi/euskotren/gtfsrt_euskotren_trip_updates.pb',
};
const RADIUS_M = 350;
const WINDOW_S = 120 * 60;
const LIMIT = 15;
// GTFS-RT enums.
const TRIP_CANCELED = 3;
const STOP_SKIPPED = 1;

const has = (o, k) => o != null && Object.prototype.hasOwnProperty.call(o, k);

const label = {
  metro(tripId) {
    const L = lookups.metro;
    const [line, headsign] = L.trips[tripId] || ['Metro', null];
    return { line, color: L.lines[line] || 'FF6505', headsign };
  },
  euskotren(tripId) {
    const L = lookups.euskotren;
    const trip = L.trips[tripId];
    const route = trip ? L.routes[trip[0]] : null;
    return {
      line: route ? route[0] : 'Euskotren',
      color: route ? route[1] : '005A8B',
      headsign: trip ? L.headsigns[trip[1]] || null : null,
    };
  },
};

module.exports = async (req, res) => {
  const q = new URL(req.url, 'http://local').searchParams;
  const op = q.get('op');
  const lat = Number(q.get('lat'));
  const lon = Number(q.get('lon'));
  const now = Math.floor(Date.now() / 1000);
  if (!FEEDS[op] || !Number.isFinite(lat) || !Number.isFinite(lon)) {
    res.statusCode = 400;
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.end(JSON.stringify({ error: 'op (metro|euskotren), lat and lon are required' }));
    return;
  }

  const near = stopsNear(op, lat, lon, RADIUS_M);
  const base = { op, generatedAt: now, attribution: ATTRIBUTION };
  if (!near.length) return send(res, { ...base, ok: true, stop: null, departures: [] }, 60);
  const ids = new Set(near.map((s) => s.id));
  // Name the station a train actually stops at (the nearest point can be an
  // entrance like "178 (Eliptikoa)"); Metro platforms "18.0" belong to "18".
  const nameOf = (id) => lookups[op].stops[String(id).split('.')[0]] || lookups[op].stops[id] || null;
  let stop = null;

  let msg;
  try {
    msg = await fetchFeed(FEEDS[op]);
  } catch (e) {
    return send(res, { ...base, ok: false, stop: nameOf(near[0].id), error: String(e.message || e), departures: [] }, 15);
  }

  const departures = [];
  for (const entity of msg.entity) {
    const tu = entity.tripUpdate;
    if (!tu) continue;
    const updates = tu.stopTimeUpdate || [];
    const firstEv = updates[0] && (updates[0].departure || updates[0].arrival);
    const started = firstEv && num(firstEv.time) && num(firstEv.time) <= now;
    for (const stu of updates) {
      if (!ids.has(stu.stopId)) continue;
      const ev = has(stu, 'departure') && num(stu.departure.time) ? stu.departure : stu.arrival;
      const t = num(ev?.time);
      if (!t || t < now - 30 || t > now + WINDOW_S) break;
      const explicitDelay = has(ev, 'delay');
      stop = stop || nameOf(stu.stopId);
      departures.push({
        tripId: tu.trip?.tripId || entity.id,
        ...label[op](tu.trip?.tripId),
        time: t,
        delay: explicitDelay ? num(ev.delay) : null,
        realtime: op === 'metro' || explicitDelay || Boolean(started),
        cancelled:
          tu.trip?.scheduleRelationship === TRIP_CANCELED ||
          stu.scheduleRelationship === STOP_SKIPPED,
      });
      break; // one departure per trip, even if both platforms are nearby
    }
  }
  departures.sort((a, b) => a.time - b.time);

  send(
    res,
    {
      ...base,
      ok: true,
      stop: stop || nameOf(near[0].id),
      feedTs: num(msg.header?.timestamp),
      departures: departures.slice(0, LIMIT).map((d) => ({ ...d, color: `#${d.color}` })),
    },
    20,
  );
};
