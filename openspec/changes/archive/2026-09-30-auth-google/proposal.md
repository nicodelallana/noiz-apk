# Proposal: auth-google

## Why

Bizkaia Transit requires user authentication to synchronize saved trips across devices and share trips with other users while complying with mobile store guidelines (Apple App Store Guideline 4.8 and Google Play account deletion mandates). 
Implementing native Google Sign-In and Apple Sign-In via Supabase Auth with strict Postgres Row Level Security (RLS) ensures seamless, passwordless login with zero-secret client isolation and full GDPR compliance.

## What Changes

- Implement native Google Sign-In using `google_sign_in` and Supabase Auth `signInWithIdToken`.
- Implement native Sign in with Apple on iOS platforms using `sign_in_with_apple`.
- Create Supabase SQL migration for `public.profiles` table with automatic user creation trigger and strict Row Level Security (RLS).
- Implement in-app account deletion triggering complete cascade removal of user data in `auth.users`, `public.profiles`, and associated data.
- Implement `AuthRepository` domain contract and `AuthRepositoryImpl` data adapter with `flutter_secure_storage` session persistence.
- Implement Riverpod state providers for user authentication state, profile data, and login/logout actions.
- Build presentation layer authentication screen (`AuthScreen`) and user profile settings card with sign-out and account deletion confirmation dialog.

## Capabilities

### Modified Capabilities
- `auth`: Refines requirements and acceptance criteria for Google Sign-In, Sign in with Apple on iOS, session persistence, and self-service account deletion.

## Impact

- **Database**: Adds versioned migration `supabase/migrations/20260930000001_auth_profiles.sql` defining `public.profiles` and RLS policies.
- **Dependencies**: Adds `google_sign_in`, `sign_in_with_apple`, and `flutter_secure_storage` to `pubspec.yaml`.
- **Domain Layer**: Introduces `UserSession`, `UserProfile`, and `AuthRepository`.
- **Presentation Layer**: Introduces `AuthScreen`, auth guard controllers, and account management UI.
