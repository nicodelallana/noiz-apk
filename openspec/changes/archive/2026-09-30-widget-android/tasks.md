# Tasks

## 1. Flutter Widget Data Synchronization

- [x] 1.1 Implement `WidgetPayload` models and `WidgetUpdateService` in `lib/presentation/widgets/home_widget/widget_update_service.dart` that extracts upcoming departures from `MetroRepository` for saved trips with `widget_enabled = true` and persists them via `HomeWidget.saveWidgetData`. Verify with unit test in `test/presentation/widget_update_service_test.dart`.
- [x] 1.2 Connect `WidgetUpdateService` to `SavedTripsNotifier` (trip toggles, additions, deletions) and app lifecycle state updates in `AppLifecycleListener`. Verify widget update is triggered when trips change.

## 2. Android Native AppWidget

- [x] 2.1 Create widget XML layouts (`transit_widget_small.xml`, `transit_widget_medium.xml`) and provider info (`transit_widget_info.xml`) under `android/app/src/main/res/`. Verify resources are formatted and valid.
- [x] 2.2 Implement Kotlin `TransitWidgetProvider` under `android/app/src/main/kotlin/com/bizkaia/transit/widget/TransitWidgetProvider.kt` reading JSON payload from `HomeWidgetPlugin.getData`, calculating remaining minutes, formatting views, and setting launch deep-link pending intents.
- [x] 2.3 Register `TransitWidgetProvider` receiver and deep link URI filter in `android/app/src/main/AndroidManifest.xml`.

## 3. Deep Linking & Verification

- [x] 3.1 Integrate `HomeWidget.initiallyLaunchedFromHomeWidget` and `HomeWidget.widgetClicked` stream in Flutter app launch logic to route to saved trip detail when opened from widget.
- [x] 3.2 Run `dart analyze` and `flutter test` to verify zero lint warnings and all tests passing.
