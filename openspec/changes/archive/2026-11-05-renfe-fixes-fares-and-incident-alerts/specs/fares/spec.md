# Spec Delta: fares

## Purpose
Provides an integrated transit fare calculator for Bizkaia and Basque Country operators, comparing Barik contactless card pricing with occasional tickets, calculating multi-zone journeys, and applying profile discounts.

## ADDED Requirements

### Requirement: Cálculo de tarifas multimodales y comparación Barik vs Ocasional
The system SHALL compute public transit fares for all operators (Metro Bilbao, Bizkaibus, Bilbobus, Renfe Cercanías Bilbao, Euskotren, Tranvía Bilbao, Funicular Artxanda, Puente Colgante) comparing Tarjeta Barik (Creditrans monedero) against Billete Ocasional/Sencillo.

#### Scenario: Comparación de precio 1 zona en Metro Bilbao
- **WHEN** the user queries the fare for a 1-zone journey in Metro Bilbao
- **THEN** the system displays 1,02 € for Barik (Creditrans) and 2,00 € for Billete Ocasional, indicating the user savings

#### Scenario: Viaje multizona en Bizkaibus
- **WHEN** the user selects a 3-zone trip on Bizkaibus
- **THEN** the system returns 1,40 € for Barik and 2,25 € for Billete Ocasional

### Requirement: Cálculo automático de zonas por origen y destino
The system SHALL calculate the number of zones traversed when the user selects origin and destination stops.

#### Scenario: Selección de Bilbao Abando a Santurtzi en Renfe
- **WHEN** the user selects origin "Bilbao-Abando" and destination "Santurtzi" on Renfe Cercanías
- **THEN** the system identifies a 2-zone journey and calculates 1,32 € with Barik and 1,95 € with Billete Sencillo

### Requirement: Perfiles de bonificación y reglas de transbordo
The system SHALL support passenger profile reductions (Estándar, Gizatrans, Gazte, Familia Numerosa F20 y F50) and explain the 20% intermodal transfer discount within 50 minutes using Barik.

#### Scenario: Tarifa reducida Gizatrans en Bilbobus
- **WHEN** the user selects profile "Gizatrans" for Bilbobus
- **THEN** the system displays the reduced rate of 0,32 € compared to the occasional ticket of 1,30 €
