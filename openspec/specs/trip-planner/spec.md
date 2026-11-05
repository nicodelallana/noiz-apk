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

### Requirement: Detección y notificación de incidencias y retrasos en itinerarios
The system SHALL evaluate active service alerts and delays for any searched transit route or itinerary, warning the user if any leg is affected and passing delay details to live lock-screen tracking.

#### Scenario: Itinerario con línea afectada por incidencia
- **WHEN** the user searches for a route whose suggested leg operates on a line with an active disruption
- **THEN** the itinerary card displays a prominent alert banner detailing the delay or disruption

#### Scenario: Seguimiento en directo de viaje con retraso
- **WHEN** the user starts tracking a journey that has an active delay or disruption
- **THEN** the system passes the delay seconds and disruption notice to the live lock-screen notification
