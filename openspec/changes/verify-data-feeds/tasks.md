# Tasks: verify-data-feeds

## 1. Feed Verification Harness Implementation

- [ ] 1.1 Create `tools/verify_feeds.sh` defining the catalog of endpoints from section 5 (Metro Bilbao, Bizkaibus, Bilbobus, Euskotren, Renfe, Moveuskadi) with status code, Content-Type, and ETag/Last-Modified header checks.
- [ ] 1.2 Implement Protobuf stream validation in `tools/verify_feeds.sh` to check payload sizes and GTFS-Realtime header attributes.
- [ ] 1.3 Make `tools/verify_feeds.sh` executable and run it locally to verify all live endpoints, outputting a structured summary report.

## 2. Legal & Data Licensing Audit

- [ ] 2.1 Audit licenses, terms of reuse, and commercial/redistribution rules for each transit authority and document findings in `docs/licencias-datos.md`.
- [ ] 2.2 Formulate required attribution strings for the mobile application (Settings → About) in `docs/licencias-datos.md`.

## 3. Automated CI Monitoring & Validation

- [ ] 3.1 Create GitHub Actions workflow `.github/workflows/verify-feeds.yml` running weekly feed checks with automated error alerting.
- [ ] 3.2 Validate the change structure with `openspec validate verify-data-feeds`.
