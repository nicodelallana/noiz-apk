# Spec Delta: widget

## ADDED Requirements

### Requirement: Android AppWidget provider
The system SHALL provide native Android Home Screen widgets in small (2x1) and medium (4x2) layouts that display the next departures of trips with `widget_enabled = true`.

#### Scenario: Visualización de salidas en Android
- **WHEN** the widget is placed on the Android home screen and at least one trip is configured with widget enabled
- **THEN** the widget displays the line badge, destination, departure time, and remaining minutes calculated from precomputed local data

#### Scenario: Sin viajes habilitados para widget
- **WHEN** the user has saved trips but none with `widget_enabled = true`
- **THEN** the widget displays an informative message guiding the user to enable a trip in the app

### Requirement: Interacción y navegación desde widget
The system SHALL support deep linking when the user taps on a trip inside the Android widget to open the application directly at the relevant departures view.

#### Scenario: Toque en viaje del widget
- **WHEN** the user taps on a specific trip row in the Android widget
- **THEN** the system launches the app navigating to the trip detail or departure timetable
