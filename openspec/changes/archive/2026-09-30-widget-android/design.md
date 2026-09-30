# Design: Android Home Screen Widget

## Context

See `proposal.md` for user motivation. In accordance with `spec.md` §10, widgets cannot reliably run Flutter/Dart code in the background without high memory overhead and OS throttling. Therefore, the Flutter app calculates the upcoming 12 hours of departures using the local SQLite GTFS timetable and stores them as a versioned JSON payload in shared storage (`SharedPreferences` on Android) via `home_widget`. The native Android widget (`TransitWidgetProvider`) reads this precalculated payload to display accurate departure times and remaining minutes with zero network latency.

## Goals / Non-Goals

**Goals:**
- Provide Android AppWidget layouts (2x1 compact, 4x2 expanded) for home-screen glanceability.
- Precalculate upcoming 12-hour departures for all saved trips marked with `widget_enabled = true`.
- Serialize scheduled times into versioned JSON via `home_widget`.
- Support deep linking from widget clicks into `bizkaiatransit://trip/{id}` opening the Flutter app.
- Provide clear visual fallback states when no trips are saved or widget is disabled.

**Non-Goals:**
- iOS WidgetKit extension (scheduled as the next companion step).
- Background polling via `WorkManager` for real-time delays (will be layered in `realtime-overlay` change).

## Decisions

### 1. Precalculated timeline payload structure
- Structure follows `spec.md` §10:
  ```json
  {
    "v": 1,
    "generated_at": "2026-09-30T09:00:00Z",
    "trips": [
      {
        "id": "uuid-or-id",
        "name": "Casa -> Trabajo",
        "origin_name": "San Mamés",
        "destination_name": "Bagatza",
        "line": "L2",
        "departures": [
          { "sched": "2026-09-30T09:12:00", "rt_delay_s": 0 },
          { "sched": "2026-09-30T09:22:00", "rt_delay_s": 0 }
        ]
      }
    ]
  }
  ```
- *Rationale*: Compact (< 10 KB), self-contained, no network or database queries required from Android widget process.

### 2. Native RemoteViews vs Jetpack Glance
- Decision: Use classic Android `RemoteViews` with `AppWidgetProvider`.
- *Rationale*: Zero extra library dependencies, maximum backwards compatibility from Android 8+ up to Android 15, no Jetpack Compose compiler plugin overhead.

### 3. Deep Linking via `home_widget` Launch Intent
- Tapping on a trip card in the widget triggers a `PendingIntent` generated through `HomeWidgetLaunchIntent.getActivity` targeting `bizkaiatransit://trip/<tripId>`.
- In Flutter, `HomeWidget.initiallyLaunchedFromHomeWidget()` and `HomeWidget.widgetClicked.listen(...)` handle navigating to the trip detail.

## Risks / Trade-offs

- [Clock drift between system time and precalculated departures] → The native widget calculates `remainingMinutes = (departureTime - currentTime)` dynamically on every tick or widget refresh.
- [App not opened for >12 hours] → If all precomputed departures have passed, widget gracefully renders "Abre la app para actualizar horarios" (Open app to refresh).
