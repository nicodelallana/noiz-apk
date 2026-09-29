# Design: bootstrap-project

## Context

See [proposal.md](proposal.md) for motivation.
The repository is starting from an empty repository on Fedora Linux. The developer workstation currently lacks a global Flutter SDK and Supabase CLI installation. The project requires an offline-first architecture for five public transit operators in Bizkaia, zero cloud cost initially, strict isolation of API keys/secrets, high-performance Lottie animations, and resilience against network overloads and external API failures.

## Goals / Non-Goals

**Goals:**
- Provide a deterministic, version-pinned Flutter environment setup using FVM (`.fvmrc`) and a helper script (`tools/bootstrap_env.sh`).
- Establish standard directory architecture: `lib/core`, `lib/data`, `lib/domain`, `lib/presentation`, and `lib/l10n`.
- Enforce strict static analysis rules via `very_good_analysis` (`strict-casts`, `strict-inference`, `strict-raw-types`).
- Protect against secret leakage via `.gitignore` and provide safe environment templates (`env/dev.example.json`, `env/prod.example.json`).
- Provide local Supabase Docker scaffolding (`supabase/config.toml`) so development does not depend on cloud provisioning.
- Establish agent guidelines and engineering rules for Flutter, Lottie animations, and network overload resilience (`.agents/skills/flutter-guidelines/SKILL.md`).
- Configure continuous integration in GitHub Actions (`.github/workflows/ci.yml`).

**Non-Goals:**
- Building concrete transit operator UI screens (handled in subsequent changes, e.g. `metro-departures`).
- Connecting to live cloud Supabase instances or registering OAuth client credentials.
- Ingesting GTFS feeds or implementing real-time protobuf parsers (handled in `gtfs-pipeline` and `realtime-overlay`).

## Decisions

### 1. Version Pinning & SDK Bootstrap (`FVM`)
- **Decision**: Pin Flutter `stable` (3.29.x) using `.fvmrc`. Provide `tools/bootstrap_env.sh` to check prerequisites, install FVM or direct Flutter SDK, and verify toolchains.
- **Alternatives considered**:
  - *Unpinned system Flutter*: Causes divergence across development machines and CI runners.
  - *Docker container for development*: Adds overhead for mobile UI development and emulator connectivity.

### 2. Layered Clean Architecture
- **Decision**: Standardize directory layout under `lib/`:
  - `core/`: Network clients, rate limiting, error handling, time/timezone utilities (`Europe/Madrid`), environment configuration.
  - `data/`: GTFS database adapters, remote API clients, local persistence repositories.
  - `domain/`: Pure Dart entities (`Stop`, `Route`, `Trip`, `Departure`, `Alert`), repository interfaces, value objects. Zero Flutter imports.
  - `presentation/`: Riverpod controllers, widgets, screen routers (`go_router`), localization, theme.
  - `l10n/`: ARB translation files (`app_es.arb`, `app_eu.arb`, `app_en.arb`).
- **Rationale**: Isolates business logic from UI, enabling fast unit testing without widget mocking.

### 3. Secret Isolation & Zero-Secret Architecture
- **Decision**: All environment variables are supplied via `--dart-define-from-file=env/<env>.json`. Git ignores `env/*.json` and exclusively tracks `env/*.example.json` containing empty placeholder keys.
- **Rationale**: Prevents accidental commits of Supabase anon keys, Google OAuth IDs, or S3 bucket URLs to public Git repositories.

### 4. Network Resilience & Overload Protection Strategy
- **Decision**: Configure a unified HTTP network stack in `lib/core/network/` based on `Dio`:
  - **Timeouts**: Connect timeout = 5 seconds, receive timeout = 10 seconds.
  - **Caching**: HTTP cache interceptor supporting `ETag` and `If-Modified-Since` to eliminate redundant payload transfers on static and semi-static feeds.
  - **Rate Limiting & Debounce**: Minimum polling interval (e.g. 15 s for real-time vehicle positions, 30 s for trip updates) with token bucket / debounce protection to avoid hammering public CTB/Renfe endpoints.
  - **Degraded Fallback**: On network error, timeout, HTTP 429 (Too Many Requests), or stale data, the system automatically falls back to offline SQLite schedule data and flags output as "horario teórico" without crashing.

### 5. Lottie Animation & Fluidity Standards
- **Decision**: Establish strict performance rules for all Lottie assets:
  - File size < 50 KB per JSON/dotLottie asset.
  - Pre-cached with `LottieBuilder.asset` and `FrameRate.composition`.
  - Enclosed in `RepaintBoundary` to prevent invalidating outer widget render trees.
  - Accessibility check: If `MediaQuery.disableAnimationsOf(context)` is `true`, render the first static frame immediately without running the `AnimationController`.

### 6. Local Supabase Configuration
- **Decision**: Initialize `supabase/config.toml` and `supabase/migrations/` structure for local development via Supabase CLI (`supabase start` / Docker).
- **Rationale**: Allows offline development and automated database testing (`supabase test db`) without creating cloud resources or consuming Free tier limits.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| Workstation lacks Flutter / Dart SDK | Developer cannot execute `flutter run` immediately | `tools/bootstrap_env.sh` provides automated installation; CI runs tests and analysis independently |
| Accidental secret commit | Exposed credentials | `.gitignore` rules + CI secret scanning with `gitleaks` |
| Upstream rate limiting by CTB | Temporary block of user queries | Dio caching (`If-Modified-Since`), backoff retries, and fallback to local SQLite |
| UI jank from unoptimized animations | Dropped frames on low-end devices | `RepaintBoundary`, composition frame rates, < 50 KB asset budget |
