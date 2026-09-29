# Proposal: verify-data-feeds

## Why

Multiple transit endpoints in section 5 of the project specification (`spec.md`) are currently marked as `[POR VERIFICAR]` or inferred from third-party implementations (specifically Metro Bilbao trip updates and alerts, Renfe Cercanías GTFS-RT, and Euskotren feeds). Before developing production data pipelines and real-time adapters, section 5.9 mandates an automated verification harness (Task T0) to test HTTP response codes, Content-Type headers, cache tags (`ETag`, `Last-Modified`), and GTFS-Realtime Protobuf validity.

Additionally, terms of reuse and statutory attribution obligations (CTB CC BY 4.0, Metro Bilbao open data guidelines, Renfe terms) must be officially audited and documented in `docs/licencias-datos.md` prior to building user-facing attribution interfaces.

## What Changes

- **Verification Harness (`tools/verify_feeds.sh`)**: Automated bash/curl/python script checking all endpoints from section 5 (Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe, Moveuskadi):
  - HTTP status codes (following redirects where appropriate).
  - `Content-Type` validation (e.g. `application/x-protobuf`, `application/zip`, `application/json`).
  - Caching support: presence of `ETag` or `Last-Modified` headers.
  - Protobuf decoding: inspection of `FeedHeader.timestamp` and entity count for `.pb` feeds.
- **Legal & Data Licensing Documentation (`docs/licencias-datos.md`)**: Formal registry of open data licenses, consultation dates, permitted uses, commercial/non-commercial restrictions, and required attribution text for Settings → About.
- **Automated Health Monitoring (`.github/workflows/verify-feeds.yml`)**: Scheduled weekly CI job executing `verify_feeds.sh` to proactively detect upstream URL breaks or feed schema alterations.

## Capabilities

### New Capabilities
None. This change delivers developer tooling, verification scripts, and compliance documentation.

### Modified Capabilities
None. Behavioral requirements remain unchanged (`skip_specs: true` in `.openspec.yaml`).

## Impact

- **Affected Code**: `tools/verify_feeds.sh`, `docs/licencias-datos.md`, `.github/workflows/verify-feeds.yml`.
- **Operators Affected**: Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe Cercanías Bilbao.
- **Non-Goals**: Does not implement GTFS SQLite packaging, mobile UI widgets, or database ingestion.
- **Dependencies**: Uses standard Linux tools (`curl`, `python3` or `protoc` if available) with zero new mobile runtime dependencies.
