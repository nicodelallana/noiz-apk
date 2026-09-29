# Proposal: bootstrap-project

## Why

The repository currently lacks the base Flutter application structure, strict linting rules, version pinning, CI automation, and local development configuration. Furthermore, the developer workstation does not yet have Flutter or Supabase pre-installed, requiring reproducible bootstrapping tooling, environment configuration templates completely isolated from secrets, and agent guidelines for high-performance Flutter development, fluid Lottie animations, and network resilience against call overload.

Establishing this baseline now ensures that all subsequent feature changes (such as Metro departures and real-time ingestion) adhere to strict quality standards, clean layered architecture, and 0-cost operational constraints.

## What Changes

- **Version Pinning & Tooling Bootstrap**: Add `.fvmrc` pinning the Flutter stable channel and `tools/bootstrap_env.sh` to automate Flutter/FVM verification and setup on Fedora Linux.
- **Flutter Scaffolding**: Create the initial `pubspec.yaml` with foundational dependencies (`flutter_riverpod`, `go_router`, `drift`, `dio`, `lottie`, `freezed_annotation`) and clean directory layout under `lib/` (`core/`, `data/`, `domain/`, `presentation/`, `l10n/`).
- **Static Analysis & Code Quality**: Configure `analysis_options.yaml` extending `very_good_analysis` with strict typing (`strict-casts`, `strict-inference`, `strict-raw-types`).
- **Secret Isolation & Environments**: Add `env/dev.example.json` and `env/prod.example.json` with empty placeholder schemas, ensuring `.gitignore` prevents tracking real secrets and keys.
- **Local Supabase Scaffolding**: Create `supabase/config.toml` and migrations layout for Docker-based local execution without requiring immediate cloud Supabase setup.
- **Flutter & Resilience Agent Guidelines**: Create `.agents/skills/flutter-guidelines/SKILL.md` documenting best practices for widget performance, Lottie animations (<50 KB, RepaintBoundary, reduce motion support), and network resilience (rate limiting, Dio ETag caching, and theoretical schedule fallback).
- **Continuous Integration**: Configure `.github/workflows/ci.yml` running `dart format --output=none --set-exit-if-changed .`, `flutter analyze --fatal-infos`, and test runs on pull requests and commits to `main`.

## Capabilities

### New Capabilities
None. This change provides core tooling, project scaffolding, and environment configuration.

### Modified Capabilities
None. Spec-level behavioral requirements remain unchanged (`skip_specs: true` declared in `.openspec.yaml`).

## Impact

- **Affected Code**: Root repository configuration, `lib/` directory scaffolding, CI workflows, and local developer tooling.
- **Operators Affected**: None directly in this tooling phase; establishes foundations for all operators (Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe).
- **Non-Goals**: Does not implement GTFS data parsing, operator UI screens, backend authentication flows, or cloud deployment.
- **Dependencies**: Introduces pinned core dependencies in `pubspec.yaml` following strict review rules.
