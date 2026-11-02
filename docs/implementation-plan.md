# Implementation Plan: Reference Parity & Scope Expansion

Ranked by user impact and visual prominence, this plan outlines the step-by-step technical implementation to bring Barik into full parity with the reference competitor.

---

## Priority Order by User Impact

### Phase 1: High-Impact Design System & Theming (Parity Baseline)
1. **Design Tokens & Dark Palette:**
   - Implement `AppColors` with `--fondo: #0B0D14`, surface `#151822`, elevated surface `#1C202D`, subtle 10% borders.
   - Add ambient radial glow component matching operator brand colors.
   - Configure typography scale (`Space Grotesk` for numerals/countdowns, `Inter` for interface copy).
   - Integrate Phosphor Icons (`phosphor_flutter`).

### Phase 2: Live Activities Kit (First-Class Lock-Screen Transit Status)
2. **Shared Data Contract & Flutter Layer:**
   - Define `LiveTripState` model and state machine (`waiting`, `tracking`, `arriving`, `at_stop`, `delayed`, `disrupted`, `ended`).
   - Create `LiveTripService` interface and method channel implementation.
   - Add in-app active trip banner and "Seguir viaje / Voy a coger este tren" buttons.
3. **Android Native Implementation:**
   - `TransitLiveService` (Android Foreground Service) with `NotificationCompat`.
   - Android 16+ Live Updates / progress-centric ongoing notification with chronometer countdown.
   - High-contrast custom notification layout mirroring the reference track, line pill, and stop alerts.
   - Document Xiaomi HyperOS autostart and battery whitelist guidelines.
4. **iOS Native Live Activity & Dynamic Island:**
   - ActivityKit attributes and SwiftUI views (`LiveTripLiveActivity.swift`).
   - Compact, minimal, and expanded Dynamic Island presentations.
   - Detailed setup guide in `docs/ios-live-activities-setup.md`.
5. **Debug Simulator:**
   - Debug-only simulator screen to cycle through states on-device.

### Phase 3: Multi-Operator Domain & SQLite Ingestion (All Euskadi)
6. **Data Source Integration for all 13 Operators:**
   - Implement ingestion adapters for:
     - Metro Bilbao (L1, L2, L3)
     - Renfe Cercanías (Bilbao & Donostia)
     - Euskotren (Tren & Tranvías Bilbao / Vitoria)
     - Bizkaibus & Bilbobus
     - Dbus (Donostia)
     - TUVISA & BEI (Vitoria)
     - Lurraldebus, Álavabus, Funicular de Artxanda, La Unión
   - Update SQLite database generator (`build_transit_db.py`) to support multi-operator, multi-territory tables.

### Phase 4: UI Screens & Flows (Fidelity Parity)
7. **Departures Screen ("Inicio"):**
   - Territory & mode selector chips at top (Bizkaia, Gipuzkoa, Araba).
   - Next departure Hero card with animated horizontal progress rail and vehicle badge.
   - Delayed badge (`+X min`) vs `En directo` vs `Según horario`.
8. **"Cerca de ti" Nearby Multi-Operator Radar:**
   - Group nearby stops by pole/station across modes.
9. **Origin-to-Destination Route Planner:**
   - Multi-modal step-by-step cards with transfer walking directions and wait times.
10. **Incidents Feed ("Incidencias"):**
    - Multi-territory incident bulletin with line badges and severity.
11. **Home-Screen Widgets:**
    - Update `home_widget` implementation with operator brand colors, delay badges, and track visualization.

### Phase 5: Verification & Quality Assurance
12. Zero-issue `flutter analyze` audit.
13. Comprehensive unit & widget tests.
14. Release APK build.
15. Changelog & final documentation.
