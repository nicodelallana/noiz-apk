# barik-balance Specification

## Purpose
Provides user tracking of Barik contactless transit card balance, fare sufficiency verification against Metro Bilbao tariffs, and gated NFC assessment criteria.

## Requirements

### Requirement: Saldo manual
The system SHALL let the user enter their Barik balance manually and show its last-update date.

#### Scenario: Registro de saldo manual
- **WHEN** the user inputs their current card balance
- **THEN** the balance is stored in cents with the update timestamp and displayed in the UI

### Requirement: ¿Me llega el saldo?
The system SHALL show whether the stored balance covers a trip's fare when the fare is available from Metro Bilbao tariff data.

#### Scenario: Saldo insuficiente
- **WHEN** balance is 0,90 € and the fare is 1,80 €
- **THEN** the app shows the shortfall and does not claim certainty about real-time card contents

#### Scenario: Saldo suficiente
- **WHEN** balance is 5,00 € and the trip fare is 1,20 €
- **THEN** the app confirms the balance covers the fare with an indication of remaining balance

### Requirement: Lectura NFC (fase v2, condicionada)
The system SHALL read the Barik balance via NFC only after the legal and technical gate in section 8 has been passed.

#### Scenario: Condición previa no satisfecha
- **WHEN** technical and legal authorization from transit authorities has not been formally cleared
- **THEN** NFC balance reading remains locked and disabled in application builds
