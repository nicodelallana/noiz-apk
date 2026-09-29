# auth Specification

## Purpose
Provides user authentication, session management, identity provider integrations (Google Sign-In and Apple Sign-In), and account deletion compliance for Bizkaia Transit.

## Requirements

### Requirement: Inicio de sesión con Google
The system SHALL allow a user to sign in or create an account using their Google account, with no password.

#### Scenario: Primer inicio de sesión
- **WHEN** a new user completes Google sign-in
- **THEN** a session is created and a row in `profiles` exists for that user

#### Scenario: Cancelación
- **WHEN** the user dismisses the Google dialog
- **THEN** the app stays on the login screen without an error dialog

### Requirement: Alternativa Sign in with Apple en iOS
The system SHALL offer Sign in with Apple on iOS wherever Google sign-in is offered, unless store policy verification concludes it is not required.

#### Scenario: Inicio de sesión en dispositivo iOS
- **WHEN** an iOS user opens the authentication screen
- **THEN** the option to sign in with Apple is displayed alongside Google sign-in

### Requirement: Eliminación de cuenta
The system SHALL let the user delete their account and all associated data from within the app.

#### Scenario: Borrado confirmado
- **WHEN** the user confirms deletion
- **THEN** the auth user, profile, saved trips, shares and settings are removed and the session is closed
