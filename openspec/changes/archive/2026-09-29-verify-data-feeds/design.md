# Design: verify-data-feeds

## Context

See [proposal.md](proposal.md) for motivation.
Section 5 of `spec.md` lists the catalog of data feeds across five operators in Bizkaia. Several entries are flagged as `[POR VERIFICAR]` or inferred from third-party repositories:
- `metro-bilbao-trip-updates.pb` and `metro-bilbao-service-alerts.pb`.
- Renfe Cercanías GTFS-RT (`gtfsrt.renfe.com`).
- Euskotren real-time feeds on `data.ctb.eus`.
- Direct static GTFS download URLs for Bizkaibus, Bilbobus, and Renfe.

To fulfill Task T0 (§5.9), an automated verification script and a statutory licensing document must be created.

## Goals / Non-Goals

**Goals:**
- Implement `tools/verify_feeds.sh` capable of testing:
  - HTTP status codes (following redirects).
  - Caching headers (`ETag`, `Last-Modified`).
  - `Content-Type` matching expected format (`application/x-protobuf`, `application/zip`, `application/json`, `text/xml`).
  - GTFS-RT Protobuf validity (basic header check and payload length).
- Generate a clear status report confirming which endpoints are verified and ready for production consumption.
- Author `docs/licencias-datos.md` auditing Open Data licenses (CTB CC BY 4.0, Moveuskadi, Metro Bilbao, Renfe) and specifying mandatory attribution texts.
- Create `.github/workflows/verify-feeds.yml` to run automated weekly feed health checks.

**Non-Goals:**
- Creating Dart/Drift models or database parsers (reserved for `gtfs-pipeline` and `realtime-overlay`).
- Downloading full schedule histories or modifying mobile app UI code.

## Decisions

### 1. Verification Engine: Bash + Curl + Python Fallback
- **Decision**: Implement `tools/verify_feeds.sh` in Bash using standard `curl` flags (`-sIL`, `--max-time 15`, `-w` format strings) to retrieve headers and timing metrics.
- **Rationale**: Minimal host dependencies, executes in any Linux shell and GitHub Actions runner without container overhead.

### 2. Protobuf Stream Validation
- **Decision**: For `.pb` feeds, inspect HTTP Content-Type and payload size. If `python3` is available, parse GTFS-RT header via a lightweight Python probe; if Python protobuf libraries are absent, verify non-zero binary byte length and valid HTTP response.
- **Rationale**: Ensures the test script runs reliably on developer machines even before specialized protobuf tools are installed.

### 3. Licensing Audit & Attribution Matrix
- **Decision**: In `docs/licencias-datos.md`, structure each operator under:
  - Source Organization & Portal URL.
  - Governing License (e.g. Creative Commons Attribution 4.0 International).
  - Commercial / Mobile Redistribution Permissions.
  - Trademark / Logo Restrictions (e.g. Metro Bilbao logo protection).
  - Mandatory Attribution String for Settings → About in the app.

### 4. Scheduled Health Monitoring
- **Decision**: Configure `.github/workflows/verify-feeds.yml` scheduled to run weekly (`0 4 * * 1`) and manually dispatchable (`workflow_dispatch`).
- **Rationale**: Proactively detects when public open data URLs change or expire.

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|---|---|---|
| Upstream feed transient downtime | False positive alert in verification | Use 2 retries with 3-second delay on non-200 responses |
| Missing protobuf packages on host | Inability to decode entity count | Graceful fallback checking HTTP status and binary size > 0 |
| Operator changes URL scheme | Broken mobile app updates | Weekly CI alert opens an issue before production impact |
