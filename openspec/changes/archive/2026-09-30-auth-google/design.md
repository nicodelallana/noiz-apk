# Design: auth-google

## Context

See [proposal.md](proposal.md) for motivation.
`metro-departures` established offline-first schedules and domain models. To support cross-device synchronization of user trips and sharing codes, Bizkaia Transit requires an identity layer. 
Supabase provides authentication backed by Postgres. To comply with Apple App Store Guideline 4.8 and Google Play account deletion policies, Google Sign-In must be paired with Sign in with Apple on iOS and an in-app self-service account deletion mechanism.

## Goals / Non-Goals

**Goals:**
- Implement native Google Sign-In (`google_sign_in`) exchanging ID tokens with Supabase Auth (`signInWithIdToken`).
- Implement native Sign in with Apple (`sign_in_with_apple`) for iOS devices.
- Define `public.profiles` table with strict Row Level Security (RLS) and automatic profile provisioning trigger.
- Implement secure session persistence using `flutter_secure_storage`.
- Implement user account deletion complying with Apple Store and Google Play requirements.
- Provide clean domain contracts (`AuthRepository`, `UserSession`, `UserProfile`) and Riverpod state controllers.
- Build `AuthScreen` and account management UI with confirmation modals.

**Non-Goals:**
- Email/password authentication or magic link registration (discouraged to keep UX zero-friction and avoid credential stuffing risks).
- Social login providers other than Google and Apple.
- Saved trips syncing (handled in change 6: `saved-trips`).

## Decisions

### 1. Native ID Token Flow over Web OAuth Redirects
- **Decision**: Authenticate natively using `google_sign_in` and `sign_in_with_apple` and exchange the resulting cryptographic `idToken` with `supabase.auth.signInWithIdToken()`.
- **Rationale**: Eliminates browser redirect flickers, avoids URL scheme interception vulnerabilities, and respects native platform biometrics and credential managers.
- **Alternatives considered**:
  - *Supabase Web OAuth via browser*: Worse UX with app switches, URL scheme redirect fragility, and potential popup blocker issues.

### 2. Secure Storage for Session Credentials
- **Decision**: Configure `Supabase.initialize(..., authOptions: FlutterAuthClientOptions(localStorage: ...))` backed by `flutter_secure_storage`.
- **Rationale**: Complies with project security standards (§13.5 and MASVS-STORAGE) by storing JWT refresh tokens in iOS Keychain and Android EncryptedSharedPreferences instead of plain `SharedPreferences`.

### 3. Database Schema and Automatic Profile Trigger
- **Decision**:
  - Versioned migration: `supabase/migrations/20260930000001_auth_profiles.sql`.
  - Table `public.profiles` with `id uuid primary key references auth.users(id) on delete cascade`.
  - Postgres trigger `handle_new_user()` executing on `INSERT ON auth.users` that automatically seeds `public.profiles(id, display_name)`.
  - RLS policies:
    ```sql
    create policy "own profile" on public.profiles
      for all using (id = auth.uid()) with check (id = auth.uid());
    ```
- **Rationale**: Decouples client write latency and guarantees a profile record exists immediately upon first login.

### 4. Account Deletion Workflow
- **Decision**: Implement an RPC function `delete_user_account()` in Postgres marked `security definer`:
  ```sql
  create or replace function public.delete_user_account()
  returns void language plpgsql security definer as $$
  begin
    delete from auth.users where id = auth.uid();
  end;
  $$;
  ```
  Client invokes `supabase.rpc('delete_user_account')`, followed by clearing local secure storage and cache.
- **Rationale**: `auth.users on delete cascade` automatically cleans up `profiles`, future `saved_trips`, `trip_shares`, and `user_settings` in a single ACID transaction without exposing elevated service_role credentials to the mobile client.

### 5. Dependency Justifications
- `google_sign_in: ^6.2.1`: Official Flutter plugin for native Google authentication.
- `sign_in_with_apple: ^6.1.0`: Official plugin for Apple ID authentication required on iOS.
- `flutter_secure_storage: ^9.2.2`: Encrypted credential persistence.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| User cancels authentication dialog | App might show unhandled exception | Handled gracefully: repository treats cancellation as neutral return with no error snackbars |
| iOS App Store rejection without Apple Sign-In | Release blocked | Apple Sign-In button automatically rendered conditionally on iOS platforms |
| Token refresh network failure | User logged out unexpectedly | Keep session active locally with cached user profile and attempt background re-authentication on reconnect |
| Account deletion requested offline | Request fails | Require active network connection and show clear error message with retry prompt |
