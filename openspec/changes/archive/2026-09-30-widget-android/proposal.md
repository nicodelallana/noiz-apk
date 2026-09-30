# Proposal

## Why

Users who take public transport every day need to check departure times of their frequent trips in less than 1 second without opening the application. Following `spec.md` §10 and §19 (step 7), an Android Home Screen widget allows glanceable departure updates directly on the home screen powered by precalculated local SQLite schedules, keeping data accurate offline for up to 12 hours.

## What Changes

- Add native Android `AppWidgetProvider` in Kotlin with `RemoteViews` (2x1 and 4x2 sizes) to display the next departures of saved trips where `widget_enabled = true`.
- Implement `WidgetUpdateService` in Flutter leveraging `home_widget` to precalculate upcoming departures from `MetroRepository` and serialize them as a versioned JSON payload in shared preferences.
- Register Android widget receiver, configure `appwidget-provider` XML metadata, and implement responsive widget layouts with line badge, origin/destination, and countdown minutes.
- Support deep linking from widget tap to launch the app directly into the selected saved trip or departures view.
- Trigger widget updates automatically whenever saved trips are created, updated, or toggled in the Flutter app, as well as on app lifecycle pause.

## Capabilities

### Modified Capabilities
- `widget`: Introduces Android glanceable home-screen widget implementation, 12-hour offline timeline synchronization via `home_widget`, and deep-link tap actions.

## Impact

- Native Android code: `android/app/src/main/kotlin/com/bizkaia/transit/widget/TransitWidgetProvider.kt`, layout XMLs `transit_widget_small.xml`, `transit_widget_medium.xml`, `widget_info.xml`.
- Flutter code: `lib/presentation/widgets/home_widget/widget_update_service.dart`, `lib/domain/services/widget_sync_service.dart`.
- Lifecycles: Trip toggles in `SavedTripsScreen` and `AppLifecycleListener` trigger `WidgetUpdateService.update()`.
- Platform integration: `home_widget` plugin configured in `android/app/src/main/AndroidManifest.xml`.
