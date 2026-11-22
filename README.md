# CP Management SQL

The numbered scripts load raw GMDF data into the CP application's PostgreSQL core tables. They require the application schemas, reference data and SCD2 columns to exist.

## Operations load

Run `04_cp_app_operations.sql` with PostgreSQL 15+ using a SQL client configured to stop on errors. For example:

```powershell
psql -X -v ON_ERROR_STOP=1 -d <database> -f .\04_cp_app_operations.sql
```

The operations load now treats `(cp_id, operation_group_id)` as its stable identity. Correcting `effective_from` closes the previous version instead of creating another active identity. Existing duplicate active partner/group rows must be reconciled first; the script rejects them and creates a partial unique index for future protection.

The last completed `SUCCEEDED` batch for `GMDF` / `core.cp_app_operations` supplies the lower boundary; the first run defaults to 1900. A cutoff captured after acquiring the target lock supplies the upper boundary. Complete current-source groups are aggregated before window filtering. New keys can be inserted even when their source timestamps precede the checkpoint. An older source timestamp cannot close a newer active target version.

Closing the old version, inserting the replacement, recording the successful batch, and updating this consumer's watermark are one transaction. The old version's end equals the replacement's start; use half-open validity intervals. App-managed detail and legacy IDs are retained. The target lock serializes writers for the duration of the load.

Failures roll back both data and progress; the calling runner must report the SQL error and record any failed-run audit separately. No independent failure row survives this transaction. No new environment variables are required; use your existing secure PostgreSQL connection configuration.

### Boundaries

- Raw-ingestion watermarks are not reused or overwritten.
- Source timestamps must reflect committed, visible changes. Backdated/late arrivals require a controlled replay; a wall-clock watermark alone cannot guarantee their capture.
- Future-dated groups are deferred. Source deletes, reference-only mapping corrections, and changes of partner/group identity require separate reconciliation.
- The existing operation-group fallback to IDs 1–3 remains unchanged; those reference IDs must exist.
- The other numbered scripts have not been migrated to this checkpoint design.

## Regression checks

Run the fixtures only against an **empty disposable PostgreSQL 15+ database**, never an application database:

```powershell
psql -X -v ON_ERROR_STOP=1 -d <disposable_database> -f .\tests\04_cp_app_operations.sql
```

They exercise the actual operations script across all four source domains for initial loading, a changed version with complete aggregation, start-date corrections, unchanged retries, failed-batch exclusion, future timestamps, stale-source protection, and persisted progress. The test stops if the fixture schemas already exist. CI/CD and deployment are not configured in this workspace; run these checks before deployment.

The script and fixtures were executed successfully in isolated PGlite (PostgreSQL 18). Additional injected-failure checks confirmed rollback of the closed version, replacement insert, batch and checkpoint, and explicit rejection of duplicate active identities. Deployment against the actual application schema and PostgreSQL 15 remains to be verified.
