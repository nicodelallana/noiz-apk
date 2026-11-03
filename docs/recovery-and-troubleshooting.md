# Runbook: Error Recovery & Troubleshooting Guide

Operational procedures for diagnosing, remediating, and recovering from transport ingestion failures.

---

## 1. Automated Health & Diagnostic Checks

### 1.1. Health Endpoint
Query the service health endpoint:
```bash
curl -s http://localhost:8000/health | jq .
```
Expected output:
```json
{
  "status": "healthy",
  "service": "moveuskadi-ingestion",
  "database_connected": true,
  "scheduler_running": true
}
```

### 1.2. Ingestion Error Logs Table
Inspect recent ingestion errors directly in Supabase PostgreSQL:
```sql
SELECT
    ie.created_at,
    o.normalized_name AS operator,
    ie.error_type,
    ie.error_message,
    ie.context_data
FROM public.ingestion_errors ie
LEFT JOIN public.transport_operators o ON o.id = ie.operator_id
ORDER BY ie.created_at DESC
LIMIT 20;
```

---

## 2. Common Failure Scenarios & Recovery Procedures

### Scenario A: Upstream Operator Feed Returns 5xx or Corrupt ZIP
- **Symptom:** Ingestion job fails with `Expected ZIP archive, but magic bytes do not match` or HTTP 502/503.
- **Root Cause:** Upstream transit portal is down or publishing a partial file during maintenance.
- **Behavior of Platform:**
  - The download manager retries up to 3 times with exponential backoff.
  - If it continues failing, the error is written to `ingestion_errors`.
  - The feed version is marked `status = 'failed'`.
  - **Crucially:** The previously active feed version in `feed_versions` remains `status = 'active'`. Mobile users continue querying existing schedules without interruption.
- **Remediation:**
  - Wait for upstream operator to resolve the deployment issue.
  - Trigger manual re-sync once upstream is healthy:
    ```bash
    curl -X POST http://localhost:8000/trigger/discovery
    ```

---

### Scenario B: Catalogue Polling Timeout
- **Symptom:** `data-index.json` fails to download due to SSL handshake or timeout.
- **Root Cause:** Regional government network glitch.
- **Behavior:**
  - Structured log warning is emitted.
  - Previous operator registry and active feeds remain completely intact.
  - Scheduler retries automatically after 15 minutes.
- **Manual Verification:**
  ```bash
  python -m src.cli discover
  ```

---

### Scenario C: Emergency Rollback of a Feed Version
If a newly activated feed has bad timetable data that bypassed validation:
1. Identify the previous valid feed version:
   ```sql
   SELECT id, operator_id, format, checksum, status, created_at
   FROM public.feed_versions
   WHERE operator_id = 'YOUR_OPERATOR_UUID'
   ORDER BY created_at DESC;
   ```
2. Re-activate the previous version atomically:
   ```sql
   SELECT public.activate_feed_version('PREVIOUS_FEED_VERSION_UUID');
   ```
3. Verify that the previous feed is now `active`:
   ```sql
   SELECT id, status, activated_at
   FROM public.feed_versions
   WHERE id = 'PREVIOUS_FEED_VERSION_UUID';
   ```

---

### Scenario D: Missing Territorial Boundary Polygons
- **Symptom:** `unclassified_stops` count is high (> 5%).
- **Remediation:**
  Re-import GeoEuskadi territorial shapefiles into PostGIS:
  ```bash
  python -m src.cli import-boundaries
  ```
  Then re-run the classification stored procedure:
  ```sql
  SELECT * FROM public.classify_stops_provinces('FEED_VERSION_UUID');
  ```
