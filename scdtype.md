

Search for `Business key:|effective_start_timestamp|create temp table tmp_src|_is_current...`

The **pasted SQL and `04_cp_app_operations.sql` use different SCD2 designs**. They target the same table, but differ in key columns, history columns, source preparation, and handling of existing fields. **Don’t combine or run them as-is together.**

## Main differences

| Topic | Pasted SQL | `04_cp_app_operations.sql` |
|---|---|---|
| **Business key** | `(source_org_id, cp_id, operation_group_id)` | `(cp_id, operation_group_id, effective_from)` |
| **SCD2 dates / current flag** | Adds `eff_strt_dt`, `eff_end_dt`, `is_actv` | Uses the file’s existing `effective_start_timestamp`, `effective_end_timestamp`, `active_flag` |
| **How an old version is closed** | Sets `eff_end_dt = current_date`, `is_actv = false` | Sets `effective_end_timestamp = now()`, `active_flag = false` |
| **How a new version is opened** | Sets start to `current_date`, end to `9999-12-31`, active true | Sets start to `now()`, end to `NULL`, active true |
| **Source-to-partner mapping** | Joins through `core.cp_app_organization_unit` and `core.cp_app_cp_org_map` | Looks up an active partner directly in `core.cp_app_common_name` using `source_org_id` |
| **Operation-group mapping** | Looks up an alias without explicitly matching the source system; drops rows where the result is null | Matches the alias using the source system; if no alias matches, assigns a deterministic fallback group |
| **Source staging** | Creates a temporary **view** | Creates a temporary **table** snapshot, reused by both load steps |
| **Preserving existing fields** | Stages `cp_detail_id` as NULL and inserts NULL | Carries forward `cp_detail_id` and `legacy_operation_id` from the previous version |
| **Job metadata** | Adds and sets `etl_job_id` | Does not set `etl_job_id` in these statements |

## The most important difference: the business key

The pasted code treats `source_org_id` as part of the key. If that value changes, the row won’t match its old version; the SQL may insert a new active row while leaving the old one active.

The file treats `source_org_id` as a **tracked attribute** instead: it matches using `cp_id`, `operation_group_id`, and `effective_from`, then compares `source_org_id` and source dates. A change to one of those compared values can close the active version and insert a replacement.

The file also includes `effective_from` in the key. That means if `effective_from` changes, it is treated as a **different key**, not as a change to the same entity. Whether that’s correct depends on the business meaning of the field.

## The date columns are not interchangeable

In the pasted SQL, `effective_from` and `effective_to` are values derived from source events. The additional `eff_strt_dt` and `eff_end_dt` represent the SCD2 version’s validity dates.

In the file, the SCD2 validity dates are named `effective_start_timestamp` and `effective_end_timestamp`; `effective_from` and `effective_to` are also source/business data. So the pasted code adds a *second set* of SCD2 columns rather than using the history columns the file expects.

The pasted pattern uses `9999-12-31` as an open-ended end date. The file uses `NULL` for an open version and an active flag to indicate the current row. These are alternative conventions; consumers and constraints need to agree on which one applies.

## How each load handles a changed row

Both designs use two operations:

1. Match the source to the current target version.
2. If tracked values changed, close that version.
3. Insert a new active version if the key no longer has an active match.

The file does this inside a transaction, using one materialized source snapshot for both operations. Its insert also looks up the previous version to retain `cp_detail_id` and `legacy_operation_id`. The pasted code uses a view and inserts `cp_detail_id = NULL`, so it may both re-read source data between operations and lose that field’s existing value.

## Other source-query differences

The file filters raw GMDF records to current, non-deleted rows and joins operation aliases using the corresponding external system. It also provides a fallback operation group when no alias matches.

The pasted query does not show those raw-record filters, doesn’t use the source system to scope the alias lookup, and filters out rows where its partner or operation-group mapping is unresolved. Its grouping also includes event-level created/modified dates in some branches, so its intermediate aggregation may differ from the file’s aggregation by organization, operation text, and source system.

## Practical conclusion

The file appears designed around the table’s existing SCD2 columns and existing key definition; the pasted SQL proposes a **different schema and key**. Before choosing between them, confirm whether `effective_from` belongs in the business key and which validity-column convention the table should use. Then make the DDL, uniqueness rule, MERGE keys, and queries consistent.