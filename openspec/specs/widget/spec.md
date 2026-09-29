# widget Specification

## Purpose
Provides glanceable home-screen widgets on Android (Kotlin/RemoteViews/Glance) and iOS (SwiftUI WidgetKit) displaying next departure times without needing to launch the full application.

## Requirements

### Requirement: Widget de próximas salidas
The system SHALL provide a home-screen widget on Android and iOS that shows the next departures of the user's saved trips without opening the app.

#### Scenario: Widget con dos viajes
- **WHEN** the user has two trips with widget enabled
- **THEN** the widget shows both with their next departure time and remaining minutes

### Requirement: Funcionamiento sin abrir la app
The system SHALL keep the widget correct for at least 12 hours without the app being opened.

#### Scenario: Previsión temporal de 12 horas
- **WHEN** the app has not been launched for up to 12 hours
- **THEN** the widget displays upcoming scheduled departures using the locally precalculated timeline

### Requirement: Estados de error del widget
The system SHALL show explicit states for no trips, signed-out, stale data and active service disruption.

#### Scenario: Sin viajes guardados
- **WHEN** the user has not configured any saved trips for the widget
- **THEN** the widget displays a prompt to add a trip in the app

#### Scenario: Usuario sin sesión
- **WHEN** no authenticated user session exists and no local trips are saved
- **THEN** the widget displays an authentication required state
