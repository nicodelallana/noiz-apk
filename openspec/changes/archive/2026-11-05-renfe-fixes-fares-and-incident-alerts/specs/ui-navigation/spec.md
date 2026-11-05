# Spec Delta: ui-navigation

## MODIFIED Requirements

### Requirement: Navegación por transporte
The system SHALL organise primary screens with a persistent liquid-glass capsule tab bar providing access to Inicio (horarios/salidas), Mapa, Alertas, and Tarifas (calculadora de precios multimodales sin barrera de inicio de sesión).

#### Scenario: Pestaña de tarifas en lugar de cuenta
- **WHEN** the user opens the bottom navigation bar
- **THEN** the fourth tab is labelled "Tarifas", navigates to the fare consultation screen, and does not require account login

#### Scenario: Exploración por modo de transporte
- **WHEN** the user selects a specific transport mode tab
- **THEN** the view presents departures, lines, stops, and alerts scoped to that operator
