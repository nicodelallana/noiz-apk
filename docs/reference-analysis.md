# Reference Analysis: Garraio vs Barik Parity

Comprehensive technical and UX analysis of the competitor application ("Garraio" — web portal `https://garraio.es/` and video suite: `Garraio_video_no_watermark.mp4`, `Garraio_video_no_watermark (1).mp4`, and `Garraio_video_no_watermark_hd.mp4`).

---

## 1. Executive Summary & Brand Identity Boundaries
- **Reference Product:** Garraio, an independent public transit companion for the Basque Country (Euskadi) covering Bizkaia, Gipuzkoa, and Araba across rail, tram, metro, urban and interurban buses, and funicular.
- **Barik Mission:** Reproduce the UI layout, information hierarchy, live status transitions, motion curves, multi-operator coverage, widgets, and lock-screen Live Activities as faithfully as possible, while retaining Barik's authentic brand identity, Phosphor iconography, custom Lottie animations, and official open-data compliance (no scraping, CC BY 4.0 attribution, strict licensing).

---

## 2. Screen-by-Screen Inventory with Video Timestamps

### Screen A: Live Departures / Home ("Inicio")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:06 - 00:08], [00:24 - 00:29], [00:45 - 00:49]
  - `Garraio_video_no_watermark (1).mp4`: [00:11 - 00:20], [00:32 - 00:37]
  - `Garraio_video_no_watermark_hd.mp4`: [00:10 - 00:24]
- **Visual Elements & Layout:**
  - Top ambient backdrop glow (`--fondo: #0B0D14` with radiant diffuse orbs colored by active operator).
  - Mode / Operator chip selector at the top (Pill shape, horizontal scroll or segment: Cercanías, Metro, Euskotren, Tranvía, Bizkaibus, Bilbobus, Dbus, Tuvisa, Lurraldebus, Alavabus).
  - Prominent stop header with station name, directional subtitle, and distance/favorite toggle.
  - Next Departure Hero Card:
    - Bold departure time (e.g. `19:40`).
    - Delay chip (`+2 min` in amber `#FFB84D` or `En directo` in green `#2BB081` with pulsing radar dot).
    - Countdown callout: `7 min`, `9 min`.
    - Realtime vs Scheduled distinction: When scheduled, explicit cool-gray tag `Según horario` and struck-through theoretical time if delayed.
    - Animated visual track / road rail: horizontal bar representing the route line, with line color glow, start station, animated vehicle badge (train / metro / tram / bus) smoothly moving at proportional progress (0.0 to 1.0), and destination marker pin.
  - Secondary departures list: Next 3 to 5 departures with line badge (e.g., `C-3`, `L1`, `A3115`, `28`, `BEI`), headsign/destination, scheduled/realtime badge, and countdown.

### Screen B: Live Moving Vehicle Map ("Mapa en directo")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:20 - 00:23]
  - `Garraio_video_no_watermark_hd.mp4`: [00:12 - 00:17]
- **Visual Elements & Layout:**
  - Dark-mode vector transit map (clean high-contrast cartography, dark slate landmasses, glowing route paths).
  - Vehicle markers moving smoothly along transit route geometries without abrupt teleports (interpolated between GPS/GTFS-RT updates).
  - Vehicle marker style: Circular/rounded badge with operator line color, line icon (bus/train/metro), heading bearing indicator, and line badge.
  - Tapping a vehicle expands a bottom sheet showing: Headsign, next stop, delay in minutes, speed, and button to "Seguir viaje" (Follow trip).

### Screen C: Nearby Transit Multi-Operator Hub ("Cerca de ti")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:30 - 00:33]
  - `Garraio_video_no_watermark_hd.mp4`: [00:25 - 00:31]
- **Visual Elements & Layout:**
  - Radar-style radius locator showing all stops within walking distance across all operators (e.g. at Moyua Plaza: Metro Bilbao L1/L2, Bilbobus stops, Bizkaibus airport line).
  - Cards grouped by station/pole, showing upcoming lines and immediate departure minutes.
  - Quick-switch filter: "Todos", "Tren/Metro", "Bus", "Tranvía".

### Screen D: Step-by-Step Route Planner ("Rutas con transbordo")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:34 - 00:38]
  - `Garraio_video_no_watermark_hd.mp4`: [00:32 - 00:37]
- **Visual Elements & Layout:**
  - Origin -> Destination search inputs (does not require knowing technical stop names; supports popular landmarks and municipalities like "Santurtzi" to "Zarautz").
  - Summary header: Total trip time (e.g. `1h 39 min`), departure & arrival times, transfer count (`1 transbordo`).
  - Step breakdown cards connected by continuous vertical track line:
    - Step 1 (Departure transit leg): Start time, station, line chip, direction, stop count & leg duration (e.g. `18 paradas · 22 min en metro`).
    - Transfer leg: Detailed walking instruction (`Baja en San Mamés -> Sal por salida Luis Briñas -> Anda 4 min (180 m) hasta Bilboko Autobus Geltokia -> Esperas 8 min`).
    - Step 2 (Connecting transit leg): Next departure time, operator badge, destination, arrival time.
  - Action footer: Button `Voy a coger este viaje` / `Seguir viaje` to activate live lock-screen tracking.

### Screen E: Lock-Screen Live Travel Status & Dynamic Island ("Viaje en directo")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:39 - 00:44]
  - `Garraio_video_no_watermark (1).mp4`: [00:07 - 00:10], [00:37 - 00:44]
  - `Garraio_video_no_watermark_hd.mp4`: [00:38 - 00:44]
  - Web demo: `/demo/viaje.html` & `demos.js` (`.nvp` live card component)
- **Visual Elements & Layout:**
  - Android ongoing notification & iOS Live Activity banner:
    - **Header:** Line badge (`C-3`, `L1`, `A2153`), status badge (`En directo` with pulsing dot or `+2 min` amber), transfer indicator (`1 transbordo`).
    - **Main metric:** Giant remaining countdown (`14 min · 4 paradas`).
    - **Instruction:** Action directive in bold (`Bájate en San Mamés` or `Cambias de línea: dirígete al andén 2`) with subtitle (`Próxima parada: Deusto`).
    - **Live Progress Track:** Horizontal track with filled gradient line showing exact train/bus progress between origin and destination, vehicle icon moving along track, destination station pin.
    - **Arrival State (`nvp__fin`):** Success banner (`Has llegado a Bilbao-Abando · Renfe Cercanías · 38 min`).
  - Dynamic Island (iOS):
    - **Compact Leading:** Line badge with operator color.
    - **Compact Trailing:** Countdown timer (e.g., `4m`).
    - **Minimal:** Line icon + dynamic countdown.
    - **Expanded:** Full route progress track, upcoming stop, delay badge, and arrival time.

### Screen F: Home-Screen Widgets ("Widgets")
- **Observed:**
  - `Garraio_video_no_watermark (1).mp4`: [00:45 - 00:52], [00:58 - 01:02]
  - Web demo: `/demo/inicio.html` & `demos.js` (`.wdg` component)
- **Visual Elements & Layout:**
  - **Widget 1: "Tu salida" (Next Departure):**
    - Line badge, origin -> destination arrow, status badge (`En directo`).
    - Scheduled time (`07:42`), countdown (`9 min`), struck-out time if delayed.
    - Mini track visual with moving vehicle dot.
  - **Widget 2: "Tu línea" (Line Overview):**
    - Full route status, frequency, vehicle positions along the line.
  - **Widget 3: "Puntualidad":**
    - Live on-time percentage (e.g. `94% a tiempo`), current average delay.
  - **Widget 4: "Incidencias":**
    - Active alerts count, affected lines list, alert snippet.

### Screen G: Service Alerts & Incidents ("Incidencias")
- **Observed:**
  - `Garraio_video_no_watermark.mp4`: [00:43 - 00:44]
  - `Garraio_video_no_watermark_hd.mp4`: [00:43 - 00:44]
  - Web screenshot `/img/capturas/incidencias-720.webp`
- **Visual Elements & Layout:**
  - Summary metric counter banner: e.g. "69 avisos en Euskadi · 37 que afectan a la circulación".
  - Territory filter: Bizkaia | Gipuzkoa | Araba.
  - Incident cards with operator chip, line chip, severity icon, title, description, and affected date/time span.

---

## 3. Design Tokens (Observed & Reverse-Engineered)

```yaml
colors:
  dark:
    background: "#0B0D14"      # Deep midnight black/blue base
    surface: "#151822"         # Card background
    surfaceElevated: "#1C202D" # Modals, tooltips, secondary cards
    border: "rgba(245, 247, 255, 0.10)"
    borderStrong: "rgba(245, 247, 255, 0.16)"
    textPrimary: "#F5F7FF"     # Crisp cool white
    textSecondary: "#9198AD"   # Cool gray
    accentBrand: "#E3202B"     # Barik crimson
  status:
    realtimeGreen: "#2BB081"   # Live radar dot & text
    delayedAmber: "#FFB84D"    # +1..+5 min delays
    disruptedRed: "#F2666B"    # Major delays / cancellations
    scheduledGray: "#9198AD"   # Theoretical schedule fallback
  operators:
    renfe: "#D0142B"           # Cercanías Red
    metroBilbao: "#E8590C"     # Metro Bilbao Orange/Red
    euskotren: "#025DA9"       # Euskotren Blue
    tranbia: "#2FA650"         # Tranvía Green
    bizkaibus: "#2E9E4F"       # Bizkaibus Emerald
    bilbobus: "#D7143C"        # Bilbobus Crimson
    dbus: "#1D7FD1"            # Dbus San Sebastián Sky Blue
    lurraldebus: "#5E9424"     # Lurraldebus Lime
    tuvisa: "#12979F"          # Tuvisa Vitoria Teal
    alavabus: "#B04A8E"        # Alavabus Mauve
    artxanda: "#DC0B0B"        # Artxanda Funicular Red
    laUnion: "#30609D"         # Autobuses La Unión Navy

typography:
  display: "Space Grotesk, sans-serif"   # Numerics, countdowns, line badges
  body: "Inter, sans-serif"              # Headings, labels, instructions
  weights:
    regular: 400
    medium: 500
    semiBold: 600
    bold: 700
    black: 800

radii:
  card: 22.0
  chip: 12.0
  button: 16.0
  full: 999.0

motion:
  curveDecel: "cubic-bezier(0.23, 1, 0.32, 1)"  # Snappy entry
  curveStandard: "cubic-bezier(0.4, 0, 0.2, 1)" # Transitions
  durationFast: 200ms
  durationNormal: 350ms
  durationSlow: 500ms
```

---

## 4. Special Section: Lock-Screen Live Transit Status (Live Activities Kit Spec)

### 4.1 Information Architecture & Visual Hierarchy
1. **Top Row (Service & Status):**
   - Line Badge: Compact filled pill (e.g., `C-3`, `L1`, `A3115`) with operator color background and white bold typography.
   - Status Badge: Pulsing dot (6px) + text:
     - Real-time normal: `En directo` (`#2BB081`)
     - Real-time delayed: `+X min` (`#FFB84D`)
     - Scheduled: `Según horario` (`#9198AD`)
   - Transfer indicator (if active trip has transfers): e.g., `1 transbordo`.
2. **Primary Metric Row (Time & Distance Remaining):**
   - Left: Enormous remaining minutes display (e.g. `14` in 32pt bold) + subtext `min · 4 paradas`.
   - Right: Action directive (e.g. `Bájate en San Mamés` in 15pt bold) + subtext (`Próxima parada: Deusto` in 12pt muted).
3. **Progress Scenic Track (`trayecto-hero__via`):**
   - Background rail track: 6px height with rounded caps (`#1C202D`).
   - Active progress track: Filled gradient path with operator color (`--lc`) matching `progress` (0.0 to 1.0).
   - Moving vehicle icon: Vector glyph (train, subway, tram, bus) translated along the track line according to current trip progress.
   - Destination terminal: Pin icon / white circle at track end.
4. **Endpoint Subtitles:**
   - Origin stop name (left) -> Destination stop name (right) in 11pt muted typography.
5. **Arrival Transition (`nvp__fin`):**
   - When trip enters `at_stop` or `ended`: Card transitions smoothly to success state with checkmark badge: `Has llegado a [Destino] · [Operador] · [Duración] min`.

### 4.2 Dynamic Island States (iOS)
- **Compact Leading:** Mini line badge (e.g. `L1` or `C3`).
- **Compact Trailing:** Countdown timer `XXm` with live pulse dot.
- **Minimal:** Vehicle icon with colored ring indicator.
- **Expanded:**
  - Header: Line badge + Origin -> Destination.
  - Center: Horizontal progress track with vehicle moving.
  - Bottom: Remaining minutes, stops remaining, next action instruction.

---

## 5. Fidelity Matrix

| Element / Flow | Observed Reference | Barik Status Prior to Upgrade | Target Parity Plan |
|---|---|---|---|
| **Territory Scope** | All Euskadi (Bizkaia, Gipuzkoa, Araba) | Bizkaia only (Metro, Bizkaibus, Bilbobus) | Full expansion to 13 operators across all 3 provinces |
| **Theme & Aesthetic** | Dark midnight `#0B0D14`, surface `#151822`, glow ambient | Light mode default, slate/emerald toggle | True dark mode with operator ambient glow |
| **Lock-Screen Live Activity** | Ongoing notification with progress track, countdown, next stop | Android widget only; no lock-screen Live Activity | Full Live Activities Kit: Android ongoing notification + Live Update, iOS ActivityKit + Dynamic Island |
| **Live Vehicle Track** | Animated vehicle badge on horizontal track in hero card | Simple departure list cards | Custom painter / animated track with vehicle icon and progress fill |
| **Scheduled vs Realtime Tagging** | Strict label: `En directo` vs `Según horario` | Generic arrival without explicit distinction | High-contrast status badges: `En directo`, `+X min`, `Según horario` |
| **Nearby Stops ("Cerca de ti")** | Multi-operator radar map with departures at all nearby poles | Single-mode map | Multi-operator nearby departures hub |
| **Route Planner with Transfers** | Origin-to-destination multi-modal planner with walking steps | Basic single line view | Multi-modal transfer itinerary breakdown |
| **Incidents & Alerts** | Consolidated Euskadi alerts page with line badges | Placeholder screen | Full incident feed categorized by territory & operator |
| **Home-Screen Widgets** | 4 widget layouts (Salida, Línea, Puntualidad, Incidencias) | Single basic metro departures widget | Multi-format widget suite with operator colors and live progress |
| **Iconography & Fonts** | Bricolage / Inter / Space Grotesk, custom glyphs | Material icons, Space Grotesk | Phosphor Icons (`phosphor_flutter`), Space Grotesk + Inter |
