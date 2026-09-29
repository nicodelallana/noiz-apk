# sharing Specification

## Purpose
Allows users to securely share configured transit journeys with others via short-lived alphanumeric codes without exposing personal account information.

## Requirements

### Requirement: Compartir un viaje por código
The system SHALL let a user generate a short-lived code for a saved trip, and another user redeem it to get their own copy.

#### Scenario: Código caducado
- **WHEN** a user redeems a code older than its expiry
- **THEN** the app shows "código caducado" and creates nothing

#### Scenario: Canje exitoso
- **WHEN** an authenticated user redeems a valid unexpired share code
- **THEN** an independent copy of the trip is created in the redeeming user's saved trips

### Requirement: Privacidad al compartir
The system SHALL NOT reveal the owner's identity or email to the person redeeming the code.

#### Scenario: Respuesta de canje segura
- **WHEN** a share code is redeemed via the RPC endpoint
- **THEN** only trip configuration fields are returned without exposing user IDs or personal details
