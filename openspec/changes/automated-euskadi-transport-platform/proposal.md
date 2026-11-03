# Proposal: Automated Euskadi Public Transport Data Platform

## Problem Statement
Currently, transit data ingestion across Euskadi was partially documented with hardcoded static tables and manual download URLs. Moveuskadi and Open Data Euskadi publish an authoritative, dynamically updated JSON catalogue (`https://opendata.euskadi.eus/transport/moveuskadi/data-index.json`) encompassing 35 operators and 195 resources across all three provinces (Bizkaia, Gipuzkoa, and Araba / Álava) in multiple formats (GTFS Static, GTFS-Realtime Protobuf, SIRI XML, and NeTEx XML). 

A production-grade, fully automated data platform is required to continuously discover, download, validate, normalise, classify geographically into the 3 historical territories, and publish transit data safely into Supabase PostgreSQL + PostGIS and Supabase Storage without manual intervention, ID collisions, or service disruption.

## Target Phase
Backend Data Infrastructure & Ingestion Automation (Master Phases 1 through 8).

## Measurable Objectives
1. **Dynamic Catalog Discovery:** Automatically poll and parse `data-index.json` every 15 minutes, discovering 100% of operators and resources dynamically without hardcoded URLs.
2. **Multi-Format Processing:** Support all four primary published formats:
   - GTFS Static (.zip)
   - GTFS-Realtime (.pb Vehicle Positions, Trip Updates, Service Alerts)
   - SIRI (.xml Vehicle Monitoring, Estimated Timetable, Situation Exchange)
   - NeTEx (.zip / .xml)
   - SHP Spatial Boundaries (GeoEuskadi ETRS89 shapefiles)
3. **Collision-Proof Relational Model:** Implement source-scoped namespacing `(feed_version_id, operator_id, external_id)` in Supabase PostgreSQL + PostGIS, guaranteeing zero ID collisions across distinct operators.
4. **Authoritative Provincial Classification:** Geographically classify stops and cross-provincial routes using PostGIS `ST_Contains` / `ST_Intersects` against official GeoEuskadi territorial boundary polygons (Bizkaia 48, Gipuzkoa 20, Araba/Álava 01).
5. **Safe Publication:** Isolate imports into versioned staging sets; switch production references atomically; preserve previous versions on failure.
6. **Audited Storage:** Archive all raw payloads and catalogue snapshots into Supabase Storage under a versioned path hierarchy (`moveuskadi/catalogue/`, `moveuskadi/raw/`, `moveuskadi/processed/`, `moveuskadi/archives/`).

## Operators Affected
All 35 transport services published in Open Data Euskadi / Moveuskadi:
Metro Bilbao, BizkaiBus, BilboBus, RENFE Cercanias, RENFE Media, Euskotren (train and bus), Dbus, Tuvisa, AlavaBus, Lurraldebus operators (Goierrialdea, Ekialdebus, Guipuzkoana, Tbh, Tolosaldea, Pesa), Funicular Artxanda, Puente Colgante, Kbus, Sopelbus, EtxeBarriBus, Erandio! busa, Lejoan busa, Bermibusa, Udalbus (Eibar), Zarauzko hiribusa, Hernaniko hiribusa, Errenteria Urbanoa, Urbano de Tolosa, Lasarte, Oñati, Arrasate, Xorrola, Irunbus, and La Unión.

## Non-Goals
- Scraping unauthorized non-public portals or private APIs.
- Reverse engineering third-party mobile applications.
- Blocking GTFS ingestion on optional auxiliary formats (e.g. NeTEx or auxiliary SHP files).
