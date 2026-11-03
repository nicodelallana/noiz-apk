# Euskadi Public Transit Data Sources & Integration Audit

> **Verificado en vivo el 3 nov 2026** (en hora punta; ver `tools/vehicle-proxy/README.md`). Varias filas de esta tabla no se cumplen hoy:
> - **Bilbobus:** sin tiempo real en ningún canal oficial; todos los feeds están vacíos.
> - **Euskotren y Tranvía:** solo previsiones de llegada; el feed de posiciones está vacío.
> - **Bizkaibus:** posiciones GPS reales, pero sus "trip updates" no traen previsiones.
> - **Metro Bilbao y Renfe:** los trenes van situados en una estación, no por GPS, y sí traen previsiones.
>
> Ningún feed tiene CORS: la versión web necesita un proxy.


Comprehensive registry of official open data feeds, licenses, API specifications, and ingestion architectures for all transport operators across the Basque Country (Euskadi).

---

## 1. Operator Feeds & Integration Matrix

| Operator | Mode | Territory | Official Portal | GTFS Static URL / Feed | Real-time Protocol | License | Update Freq | Status |
|---|---|---|---|---|---|---|---|:---:|
| **Metro Bilbao** | Metro | Bizkaia | `metrobilbao.eus` / `data.ctb.eus` | `https://cms.metrobilbao.eus/get/open_data/horarios/es` | GTFS-RT (TripUpdate) / REST API | CC BY 4.0 | Weekly static / 30s RT | **Real-time + Schedules** |
| **Renfe Cercanías** | Commuter Rail | Bizkaia & Gipuzkoa | `data.renfe.com` / Mitma | `https://data.renfe.com/dataset/horarios-cercanias-bilbao` & `...donostia` | GTFS-RT / SIRI REST | Reutilización Sector Público (Ley 37/2007) / CC BY 4.0 | Monthly static / 60s RT | **Real-time + Schedules** |
| **Euskotren Tren** | Regional Rail & Topo | Bizkaia & Gipuzkoa | `euskotren.eus` / `opendata.euskadi.eus` | `https://opendata.euskadi.eus/catalogo/-/gtfs-euskotren/` | GTFS-RT / Moveuskadi | CC BY 4.0 | Monthly static / 30s RT | **Real-time + Schedules** |
| **Tranvía de Bilbao** | Tram | Bizkaia | `euskotren.eus` / `moveuskadi.euskadi.eus` | Included in Euskotren GTFS package | GTFS-RT | CC BY 4.0 | Monthly static / 30s RT | **Real-time + Schedules** |
| **Tranvía de Vitoria-Gasteiz** | Tram | Araba | `euskotren.eus` / `moveuskadi.euskadi.eus` | Included in Euskotren GTFS package | GTFS-RT | CC BY 4.0 | Monthly static / 30s RT | **Real-time + Schedules** |
| **Bizkaibus** | Interurban Bus | Bizkaia | `baliabideak.bizkaia.eus` / `data.ctb.eus` | `https://baliabideak.bizkaia.eus/opendata/bizkaibus/gtfs.zip` | GTFS-RT VehiclePosition + TripUpdates | CC BY 4.0 | Bi-weekly / 15s RT | **Real-time + Schedules** |
| **Bilbobus** | Urban Bus | Bizkaia | `bilbao.eus/opendata` / `opendata.euskadi.eus` | `https://www.bilbao.eus/opendata/es/catalogo/bilbobus-gtfs` | GTFS-RT Daily REST | CC BY 4.0 | Bi-weekly / 15s RT | **Real-time + Schedules** |
| **Dbus (Donostia)** | Urban Bus | Gipuzkoa | `dbus.eus/es/open-data/` / Open Data Euskadi | `https://opendata.euskadi.eus/catalogo/-/gtfs-dbus/` | GTFS-RT (VehiclePositions + TripUpdates) | CC BY 4.0 | Monthly static / 20s RT | **Real-time + Schedules** |
| **Lurraldebus** | Interurban Bus | Gipuzkoa | `lurraldebus.eus` / `gipuzkoa.eus` | `https://opendata.euskadi.eus/catalogo/-/gtfs-lurraldebus/` | GTFS-RT on main corridors; scheduled fallback | CC BY 4.0 | Monthly static | **Real-time + Schedules** |
| **TUVISA & BEI** | Urban Bus / BRT | Araba | `vitoria-gasteiz.org/opendata` | `https://www.vitoria-gasteiz.org/opendata/tuvisa-gtfs.zip` | GTFS-RT SIRI / REST API | CC BY 4.0 | Monthly static / 20s RT | **Real-time + Schedules** |
| **Álavabus** | Interurban Bus | Araba | `araba.eus/opendata` / `alavabus.araba.eus` | `https://opendata.euskadi.eus/catalogo/-/gtfs-alavabus/` | Scheduled times labeled `Según horario` | CC BY 4.0 | Seasonal static | **Schedules Only** |
| **Funicular de Artxanda** | Funicular | Bizkaia | `funicularartxanda.bilbao.eus` | Included in Bilbao Open Data catalog | Fixed frequency (every 15 min; 07:15 - 22:00) | CC BY 4.0 | Static | **Schedules Only** |
| **Autobuses La Unión** | Interurban Coach | Bizkaia & Araba | `autobuseslaunion.com` / Moveuskadi | Integrated in Moveuskadi interurban network | Official timetable schedules with live alerts | CC BY 4.0 | Seasonal static | **Schedules Only** |

---

## 2. Real-time vs Scheduled Policy

To ensure 100% honesty with the user, Barik strictly enforces the following classification:
- **`En directo` (Live Real-time):** Displayed ONLY when dynamic GPS telemetry or GTFS-RT feed confirms vehicle location and computed delay. Rendered in Emerald Green (`#2BB081`) with a pulsating radar beacon.
- **`+X min` (Delay Alert):** Displayed when real-time telemetry indicates deviation greater than 1 minute from timetable. Rendered in Amber (`#FFB84D`).
- **`Según horario` (Scheduled Timetable):** Displayed for operators without open live telemetry (Álavabus, Artxanda, La Unión, or off-peak branches). Rendered in Slate Gray (`#9198AD`).

---

## 3. Database Footprint & Free-Tier Optimization Budget

To respect Supabase free-tier storage (500 MB limit) and maintain instantaneous offline lookups:

```
┌────────────────────────────────────────────────────────┐
│ Offline Client Storage (SQLite inside App)             │
│ - Compressed transit.sqlite.gz: ~18 MB                 │
│ - Unpacked local SQLite DB: ~42 MB                     │
│ - Indices on (operator_id, route_id, stop_id)          │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ Cloud Backend (Supabase PostgreSQL Free Tier)          │
│ - live_trip_sessions table: ~2.5 MB (auto-pruned)      │
│ - active_service_alerts table: ~0.8 MB                 │
│ - Total Postgres storage: ~3.3 MB (< 1% of free quota) │
└────────────────────────────────────────────────────────┘
```
