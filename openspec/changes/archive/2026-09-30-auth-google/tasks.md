# Tasks

## 1. Database Migration & RLS Policies

- [x] 1.1 Create Supabase SQL migration in `supabase/migrations/20260930000001_auth_profiles.sql` defining `public.profiles`, RLS policies (`own profile`), `handle_new_user()` trigger on `auth.users`, and `delete_user_account()` RPC function
- [x] 1.2 Verify SQL migration structure and RLS security compliance against project specifications

## 2. Domain Models & Repository Contract

- [x] 2.1 Define pure domain entities (`UserSession`, `UserProfile`, `AuthStatus`) in `lib/domain/models/auth_models.dart` with immutability and equality operators
- [x] 2.2 Define `AuthRepository` interface in `lib/domain/repositories/auth_repository.dart` for sign-in with Google, sign-in with Apple, session stream, sign-out, and account deletion

## 3. Data Layer & Supabase Adapter

- [x] 3.1 Add auth dependencies (`google_sign_in`, `sign_in_with_apple`, `flutter_secure_storage`) to `pubspec.yaml`
- [x] 3.2 Implement `AuthRepositoryImpl` in `lib/data/adapters/auth_repository_impl.dart` using `supabase_flutter` `signInWithIdToken` and secure storage
- [x] 3.3 Add unit tests in `test/unit/auth_repository_test.dart` verifying sign-in handling, user cancellation, and account deletion flow

## 4. Presentation Layer & State Management

- [x] 4.1 Implement Riverpod auth providers in `lib/presentation/providers/auth_providers.dart` for auth state and current user profile
- [x] 4.2 Implement `AuthScreen` in `lib/presentation/screens/auth/auth_screen.dart` with Google and Apple sign-in buttons, privacy disclaimers, and loading feedback
- [x] 4.3 Implement `ProfileSettingsScreen` in `lib/presentation/screens/auth/profile_settings_screen.dart` with sign-out action and two-step account deletion modal

## 5. Verification & OpenSpec Validation

- [x] 5.1 Run `openspec validate auth-google` to verify compliance with schema and specifications
