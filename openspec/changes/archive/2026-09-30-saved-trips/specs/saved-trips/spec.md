# Spec Delta: saved-trips

## MODIFIED Requirements

### Requirement: Guardar un viaje
The system SHALL let an authenticated or guest user save a trip defined by operator, origin stop and destination stop, with a custom name and widget enablement flag.

#### Scenario: Guardar Bagatza → Kabiezes
- **WHEN** the user saves origin "Bagatza" and destination "Kabiezes" on Metro Bilbao
- **THEN** the trip appears in "Mis viajes" and, if enabled, is marked ready for home-screen widget export

#### Scenario: Guardado sin cuenta (invitado)
- **WHEN** an unauthenticated user saves a trip
- **THEN** the trip is stored in local storage and persists across application restarts

### Requirement: Sincronización y caché local
The system SHALL cache saved trips locally in SQLite and automatically sync them bidirectionally with Supabase Postgres when an authenticated network connection is available.

#### Scenario: Acceso sin conexión
- **WHEN** the network is unavailable
- **THEN** previously cached saved trips remain fully readable, operable, and show theoretical timetable departures

#### Scenario: Sincronización al iniciar sesión
- **WHEN** a guest user with local trips signs in
- **THEN** the local trips are merged into their remote account without duplicates

### Requirement: Aislamiento de datos
The system SHALL ensure each user can only read and modify their own saved trips (enforced by Supabase Row Level Security).

#### Scenario: Intento de acceso ajeno
- **WHEN** a user queries saved trips
- **THEN** Row Level Security restricts returned records strictly to those owned by auth.uid()
