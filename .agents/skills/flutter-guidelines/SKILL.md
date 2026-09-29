---
name: flutter-guidelines
description: Engineering guidelines for Bizkaia Transit covering Clean Architecture, Lottie animations, secret isolation, and network resilience.
allowed-tools: view_file, run_command
license: MIT
metadata:
  project: Bizkaia Transit
  version: "1.0"
---

# Flutter & Architecture Guidelines — Bizkaia Transit

This skill establishes the mandatory development standards for the Bizkaia Transit mobile application. Every developer and AI agent must adhere to these guidelines across all implementation tasks.

---

## 1. Clean Architecture & Layer Separation

```
lib/
├── core/           # Cross-cutting: network client, rate limiters, errors, theme, time (Europe/Madrid)
├── data/           # Repositories, GTFS Drift database, remote APIs, operator adapters
├── domain/         # Pure Dart entities (Stop, Route, Trip, Departure, Alert), repository contracts, use cases
├── presentation/   # Riverpod controllers, screens, widgets, routing (GoRouter)
└── l10n/           # Internationalization ARB files (es, eu, en)
```

### Strict Rules:
- **Zero UI in Domain/Data**: Never import `flutter/material.dart` or pass `BuildContext` into `domain` or `data` layers.
- **Pure Entities**: Domain entities must be plain immutable Dart classes (using `freezed` where appropriate) with zero third-party framework dependencies.
- **Typed Error Handling**: Never return untyped exceptions across layers. Use `Result<T, Failure>` or functional error patterns.
- **State Management**: Use `flutter_riverpod` with `riverpod_annotation` / code generator. Keep widgets `const` whenever possible and extract large `build` methods into separate widget classes.

---

## 2. Fluid Lottie Animations (< 50 KB & Accessible)

Lottie animations give life to the application without causing UI jank or battery drain when properly budgeted.

### Performance & Quality Standards:
- **Budget**: Every `.json` or `.lottie` file in `assets/lottie/` MUST be **under 50 KB**.
- **Isolation via RepaintBoundary**: Always wrap Lottie animation widgets inside a `RepaintBoundary` to prevent invalidating the render tree of parent/sibling widgets during animation ticks:
  ```dart
  RepaintBoundary(
    child: Lottie.asset(
      'assets/lottie/metro_loading.json',
      controller: _controller,
      frameRate: FrameRate.composition,
    ),
  )
  ```
- **Lifecycle Management**: Instantiate at most one `AnimationController` per screen, dispose it properly in `dispose()`, and use `repeat: false` for micro-interactions (e.g. checkmark upon saving a trip).
- **Accessibility (*Reduce Motion*)**: Always check system accessibility preferences:
  ```dart
  if (MediaQuery.disableAnimationsOf(context)) {
    // Show static frame or placeholder, do NOT run controller
    return const Icon(Icons.train);
  }
  ```
- **Licenses & Attribution**: Record author, source URL, and license in `assets/lottie/LICENSES.md` for every added animation.

---

## 3. Zero-Secret Isolation & Safe Environments

- **No Secrets in Git**: Never commit `.env`, `env/dev.json`, `env/prod.json`, `*.jks`, or keystores.
- **External Definitions**: Read environment values strictly through compile-time environment files:
  `flutter run --dart-define-from-file=env/dev.json`
- **Template Tracking**: Only track `env/*.example.json` containing empty placeholder values.
- **Client Security**: Do not store JWTs or session tokens in shared `home_widget` storage (App Group / SharedPreferences). Use `flutter_secure_storage` for credentials and restrict shared containers strictly to sanitized schedule data.

---

## 4. Network Resilience & Call Overload Prevention

Transit feeds (CTB S3, Bizkaibus, Renfe) are public infrastructure and must be accessed respectfully with built-in resilience.

### Anti-Overload Architecture:
1. **Configured Dio Client**:
   - `connectTimeout`: 5,000 ms.
   - `receiveTimeout`: 10,000 ms.
2. **HTTP Caching**:
   - Always evaluate `ETag` and `Last-Modified` headers.
   - Send `If-None-Match` and `If-Modified-Since` on subsequent requests to prevent downloading unchanged payloads (HTTP 304 Not Modified).
3. **Client-Side Polling Guardrails**:
   - Real-time vehicle positions: minimum polling interval = 15 seconds.
   - Real-time trip updates: minimum polling interval = 30 seconds.
   - Background fetch: minimum interval = 15 minutes.
   - Use debounce / token-bucket throttling so rapid user screen switches do not trigger duplicate HTTP calls.
4. **Graceful Degradation (Offline-First Fallback)**:
   - On network failure, timeout, or HTTP 429 (Too Many Requests), the app must NEVER display an unhandled exception or an empty view.
   - Immediately fall back to local scheduled departure times from Drift SQLite, overlaying an indicator stating `"horario teórico (sin tiempo real)"`.

---

## 5. Coding Conventions

- **Language**: Identifiers, variables, methods, and comments in **English**.
- **Localization**: UI text in Spanish, Basque, and English via `flutter_localizations` and ARB files. Never hardcode user-facing strings in widgets.
- **Timezone**: Internally compute all timestamps in UTC; convert to `Europe/Madrid` exclusively for display and for GTFS service-day resolution (> 24:00:00).
