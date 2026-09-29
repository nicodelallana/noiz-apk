# alerts Specification

## Purpose
Collects, unifies, and presents service disruption alerts from operators across Bizkaia, associating active alerts with impacted routes and saved trips.

## Requirements

### Requirement: Incidencias unificadas
The system SHALL show current service alerts from all operators, filterable by operator and by the user's saved trips.

#### Scenario: Alerta en un viaje guardado
- **WHEN** an active alert affects a line or stop used by a saved trip
- **THEN** the trip card and its widget show an alert indicator

#### Scenario: Filtrado por operador
- **WHEN** the user filters alerts by an operator such as Metro Bilbao
- **THEN** only active alerts relevant to that operator are displayed
