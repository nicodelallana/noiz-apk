# saved-trips Specification

## Purpose
Enables users to bookmark transit journeys, persist them for offline access, synchronize across devices via Supabase, and maintain strict multi-tenant data isolation.

## Requirements

### Requirement: Guardar un viaje
The system SHALL let an authenticated user save a trip defined by operator, origin stop and destination stop, with a name.

#### Scenario: Guardar Bagatza → Kabiezes
- **WHEN** the user saves origin "Bagatza" and destination "Kabiezes" on Metro Bilbao
- **THEN** the trip appears in "Mis viajes" and, if enabled, in the widget

### Requirement: Sincronización y caché local
The system SHALL cache saved trips locally and sync them with the backend when online.

#### Scenario: Acceso sin conexión
- **WHEN** the network is unavailable
- **THEN** previously cached saved trips remain fully readable and operable locally

### Requirement: Aislamiento de datos
The system SHALL ensure each user can only read and modify their own saved trips (enforced by row-level security).

#### Scenario: Intento de acceso ajeno
- **WHEN** a user queries saved trips
- **THEN** Row Level Security restricts returned records strictly to those owned by auth.uid()
