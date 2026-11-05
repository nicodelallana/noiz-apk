# ui-navigation Specification

## Purpose
Establishes the application's multi-transport navigation structure (Metro, Bizkaibus, Bilbobus, Euskotren, Renfe), multilingual support (ES/EU/EN), and accessible motion behaviors.

## Requirements

### Requirement: Navegación por transporte
The system SHALL organise primary screens with a persistent liquid-glass capsule tab bar providing access to Inicio (horarios/salidas), Mapa, Alertas, and Tarifas (calculadora de precios multimodales sin barrera de inicio de sesión).

#### Scenario: Pestaña de tarifas en lugar de cuenta
- **WHEN** the user opens the bottom navigation bar
- **THEN** the fourth tab is labelled "Tarifas", navigates to the fare consultation screen, and does not require account login

#### Scenario: Exploración por modo de transporte
- **WHEN** the user selects a specific transport mode tab
- **THEN** the view presents departures, lines, stops, and alerts scoped to that operator

### Requirement: Idiomas
The system SHALL support Spanish, Basque and English, defaulting to the device language.

#### Scenario: Idioma predeterminado del sistema
- **WHEN** the device system language is Basque
- **THEN** the app interface automatically renders using Basque localization

### Requirement: Animaciones respetuosas
The system SHALL disable non-essential animations when the OS "reduce motion" setting is on.

#### Scenario: Reducción de movimiento activa
- **WHEN** the system accessibility setting for reduce motion is enabled
- **THEN** Lottie animations and decorative transitions are replaced with static frames
