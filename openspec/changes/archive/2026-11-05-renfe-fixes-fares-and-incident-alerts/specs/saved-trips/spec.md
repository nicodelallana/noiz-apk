# Spec Delta: saved-trips

## MODIFIED Requirements

### Requirement: Guardar un viaje
The system SHALL let an authenticated or guest user save a trip defined by operator, origin stop and destination stop across all supported operators (Metro, Bizkaibus, Bilbobus, Euskotren, Renfe), with a custom name and widget enablement flag.

#### Scenario: Guardar viaje de Renfe Cercanías
- **WHEN** the user saves a Renfe Cercanías journey from "Bilbao-Intermod. Abando" to "Santurtzi"
- **THEN** the dialog displays the origin station name correctly, populates reachable destinations for that operator, and persists the journey with operator "renfe"

#### Scenario: Guardar Bagatza → Kabiezes
- **WHEN** the user saves origin "Bagatza" and destination "Kabiezes" on Metro Bilbao
- **THEN** the trip appears in "Mis viajes" and, if enabled, is marked ready for home-screen widget export

#### Scenario: Guardado sin cuenta (invitado)
- **WHEN** an unauthenticated user saves a trip
- **THEN** the trip is stored in local storage and persists across application restarts
