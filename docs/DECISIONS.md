# Architectural & Design Decisions (ADR)

This document logs all key engineering and design decisions made to achieve faithful parity with the reference competitor (Garraio) while preserving Barik's authentic brand and legal integrity.

---

## Decision 1: Visual Theme & Dark Mode Baseline
- **Context:** The reference app uses a signature deep midnight dark palette (`--fondo: #0B0D14`, surface `#151822`, elevated `#1C202D`) with diffuse ambient glows matching the active operator color. Barik had only a light mode with basic red/green toggles.
- **Decision:** Establish dark mode as the default high-fidelity theme for Barik, utilizing the exact `--fondo: #0B0D14`, `--superficie: #151822`, and `--superficie-2: #1C202D` surfaces. Add a soft dynamic ambient radial glow at the top of screens that smoothly tint transitions when switching between operators. Maintain Barik's clean typography (Space Grotesk for numbers/badges, Inter for text).
- **Consequences:** Provides the modern high-end transit aesthetic observed in the reference, improves outdoor legibility and battery efficiency on OLED screens (Xiaomi 15).

---

## Decision 2: Multi-Operator Unified Data Model
- **Context:** Barik was originally constrained to Bizkaia (Metro Bilbao and Bizkaibus). The reference covers all 3 Basque territories (Bizkaia, Gipuzkoa, Araba) and 13 distinct operators and services.
- **Decision:** Normalize all operators into a clean, extensible SQLite schema and Dart domain model:
  - `TransitOperator`: id, name, mode, territory, brandColor, hasRealtime, gtfsStaticUrl, gtfsRtUrl.
  - `TransitRoute`: routeId, operatorId, mode, territory, routeShortName, routeLongName, color, textColor.
  - `TransitStop`: stopId, operatorId, stopName, stopLat, stopLon, territory, parentStation.
  - `TransitDeparture`: tripId, routeId, operatorId, lineCode, destination, scheduledTime, actualTime, delaySeconds, isRealtime, status (`scheduled | tracking | arriving | at_stop | delayed | disrupted | ended`).
- **Consequences:** All features (Departures, Cerca de ti, Route Planner, Widgets, Live Activities) work uniformly across any operator without hardcoded operator logic.

---

## Decision 3: Live Activities Kit — Native Lock-Screen Architecture
- **Context:** The reference video demonstrates a live transit status notification with real-time countdown, animated vehicle track, and "Bájate en..." stop alerts.
- **Decision:**
  - **Data Contract:** Shared `LiveTripState` structure serialized as JSON between Flutter, Android Foreground Service, iOS ActivityKit, and Supabase.
  - **Android:** Implement a dual-tier architecture:
    1. Modern Android 16 Live Updates style / `NotificationCompat.Builder` with `setProgress`, chronometer base, and `CATEGORY_TRANSPORT` / `CATEGORY_WORKOUT`.
    2. Custom `RemoteViews` with high-contrast layout matching the reference's scenic track, line pill, and stop indicators.
    3. Dedicated Foreground Service with `foregroundServiceType="specialUse"` or `"remoteMessaging"`, handling Android 14/15 timeouts and Xiaomi HyperOS autostart.
  - **iOS:** Complete ActivityKit implementation with Swift Widget Extension (`ActivityConfiguration`, `ActivityAttributes`, `ContentState`) supporting lock screen, Dynamic Island compact leading/trailing, minimal, and expanded views.
  - **Absolute Timestamps:** Send absolute arrival timestamps so Android's `setChronometerCountDown` and iOS's `Text(timerInterval: ...)` render fluid countdowns locally without draining battery with 1-second background loops.

---

## Decision 4: Open Data Compliance & Footprint Optimization
- **Context:** AGENTS.md strictly prohibits scraping private APIs and demands compliance with CC BY 4.0 licenses. Free-tier Supabase has a 500 MB database limit.
- **Decision:**
  - Ingest public, official GTFS feeds from Moveuskadi / Open Data Euskadi and CTB.
  - Precompute static schedules into an offline SQLite database (`transit.sqlite`) packaged and synced via `ScheduleSyncService`.
  - Store only active live trip sessions and real-time incident caches in Supabase Postgres, keeping database size well under 25 MB and ensuring zero free-tier exhaustion.

---

## Decision 5: Real-time vs Scheduled Transparency
- **Context:** The reference explicitly promises: *"Nunca te vendemos un horario como si fuera directo."*
- **Decision:** In every UI surface (card, widget, notification), clearly label realtime arrivals with a pulsing emerald radar dot and `En directo` or amber `+X min`. Label non-realtime services with `Según horario` and cool-gray typography.
