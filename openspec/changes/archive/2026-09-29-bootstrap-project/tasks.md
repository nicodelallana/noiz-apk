# Tasks: bootstrap-project

## 1. Tooling, FVM & Environment Configuration

- [x] 1.1 Pin Flutter SDK stable version in `.fvmrc` and verify file content.
- [x] 1.2 Create `tools/bootstrap_env.sh` to check, install, and configure FVM/Flutter on Fedora Linux, and verify executable permissions with `bash -n tools/bootstrap_env.sh`.
- [x] 1.3 Create environment templates `env/dev.example.json` and `env/prod.example.json` with placeholder schemas and verify `.gitignore` ignores `env/*.json`.

## 2. Flutter Project Scaffolding & Static Analysis

- [x] 2.1 Create `pubspec.yaml` declaring application metadata and pinned foundational dependencies (`flutter_riverpod`, `go_router`, `drift`, `dio`, `lottie`, `freezed_annotation`, `very_good_analysis`).
- [x] 2.2 Create `analysis_options.yaml` extending `package:very_good_analysis/analysis_options.yaml` with strict language mode rules.
- [x] 2.3 Create clean architecture directory structure under `lib/` (`core/`, `data/`, `domain/`, `presentation/`, `l10n/`) with base entry point `lib/main.dart` and placeholder barrel files.

## 3. Local Supabase & Schema Scaffolding

- [x] 3.1 Create `supabase/config.toml` configuring local Docker-based emulation without requiring cloud Supabase provisioning.
- [x] 3.2 Create initial SQL migration `supabase/migrations/20260929000000_initial_schema.sql` implementing user profiles, saved trips, trip shares, and user settings with Row Level Security (RLS) and the `redeem_trip_share` RPC function.

## 4. Agent Guidelines for Flutter, Lottie & Network Resilience

- [x] 4.1 Create `.agents/skills/flutter-guidelines/SKILL.md` documenting clean architecture conventions, Lottie performance rules (<50 KB, RepaintBoundary, reduce motion), and network resilience patterns (rate limiting, Dio ETag caching, circuit breaker, offline schedule fallback).

## 5. CI Workflow & Baseline Verification

- [x] 5.1 Create GitHub Actions workflow `.github/workflows/ci.yml` for automated linting, formatting check, and test execution.
- [x] 5.2 Verify repository integrity and run `openspec validate bootstrap-project` to confirm all change requirements and planning artifacts pass validation.
