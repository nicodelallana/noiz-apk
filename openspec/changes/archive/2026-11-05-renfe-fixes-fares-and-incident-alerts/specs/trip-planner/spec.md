# Spec Delta: trip-planner

## ADDED Requirements

### Requirement: Detección y notificación de incidencias y retrasos en itinerarios
The system SHALL evaluate active service alerts and delays for any searched transit route or itinerary, warning the user if any leg is affected and passing delay details to live lock-screen tracking.

#### Scenario: Itinerario con línea afectada por incidencia
- **WHEN** the user searches for a route whose suggested leg operates on a line with an active disruption
- **THEN** the itinerary card displays a prominent alert banner detailing the delay or disruption

#### Scenario: Seguimiento en directo de viaje con retraso
- **WHEN** the user starts tracking a journey that has an active delay or disruption
- **THEN** the system passes the delay seconds and disruption notice to the live lock-screen notification
