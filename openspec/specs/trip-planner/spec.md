# trip-planner Specification

## Purpose
Helps users discover transit connections between origins and destinations across operators in Bizkaia, offering route suggestions and flexible stop search.

## Requirements

### Requirement: Sugerir líneas para un origen y destino
The system SHALL, given an origin and a destination, list the transit options (operator, line, next departures) that connect them.

#### Scenario: Barakaldo → Mungia
- **WHEN** the user searches from a stop in Barakaldo to a stop in Mungia
- **THEN** the app lists direct options if any exist, otherwise options with transfers (from v1.x), each with duration and next departure

### Requirement: Búsqueda de paradas
The system SHALL search stops by name (accent- and case-insensitive, Spanish and Basque names) and by proximity.

#### Scenario: Búsqueda bilingüe insensible a tildes
- **WHEN** the user types a stop name in Spanish or Basque, with or without diacritics
- **THEN** matching transit stops are returned promptly sorted by relevance or distance
