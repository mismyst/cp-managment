# CP Management data loads: an onboarding guide

This guide explains the data journey in **time order**, the layers and schemas it
passes through, and the terminology a new data engineer will encounter. It is
based on the project documents and SQL in this workspace; it is not evidence that
every proposed component is deployed or running in production.

> **Important distinction:** There are two different things called “conform”.
> The **upstream GMDF Conform layer** is a source for CP Management. A separate
> **CP Management conformed/reporting layer** is proposed for later and is not
> part of the current two-layer application design.

“Temporal flow” here means the chronological sequence and handling of time and
history. The inspected architecture and SQL do not establish that the Temporal
workflow orchestration product is used; its workflows, schedules and retry
settings cannot be inferred from these files.

## 1. Start with the business

**CP** means **collaboration partner**: an external manufacturing, packaging,
testing or distribution partner overseen by PR&D Quality. The application
brings together information about partners, their sites, operations, quality
events and risk reviews. A **QPR** is the Quarterly Performance Report used to
review and report a partner's performance and risk.

A practical question might be: “Which changes and deviations relate to this
partner this quarter?” To answer it safely, the application needs to connect a
source event to the correct organization, partner, quarter and standardized
classification. The layers help preserve the original evidence while making
the data usable by the application.

## 2. The big picture: four different meanings of “layer”

```text
TIME -------------------------------------------------------------------->

Source systems             Enterprise data platform             CP Management
Veeva, TrackWise, SAP ...  GMDF products on Redshift            PostgreSQL
        |                            |                                |
        v                            v                                v
 Source records --> GMDF Refine / other inputs --> GMDF Conform --> RAW
                                                      |               |
                                      read-only extract               v
                                                               REFINED / CORE
                                                               + ref, ops, etc.
                                                                      |
                                                                      v
                                                               app, views, QPR
                                                                      |
                                                                      v
                                                        CP reporting layer?
                                                        DEFERRED, if needed
```

The diagram is a conceptual view, not a claim that every source always follows
the same upstream path. The architecture says the deviation product uses
historical TrackWise data from GMDF Refine and current Veeva data through a
Redshift data share; other products have their own lineage.

| Term | Owner/location | Meaning |
|---|---|---|
| Source system | Outside CP Management | System where a business record originates, such as a quality-management system. |
| GMDF Refine | Upstream enterprise platform | An upstream transformation layer feeding several GMDF products. It is **not** the CP application's refined layer. |
| GMDF Conform | Upstream enterprise platform, AWS Redshift | Published GMDF data products, exposed as materialized views; CP Management reads these as sources. |
| CP raw, Layer 1 | CP Management PostgreSQL, `raw_gmdf_*` schemas | Source-shaped landing/history tables with ingestion metadata. |
| CP refined, Layer 2 | CP Management PostgreSQL, chiefly `core`, plus `ref`, `rbac`, `audit` and `ops` | The application's canonical model and supporting tables. “Core” is a schema within this layer, not a separate raw-to-core-to-refined layer. |
| CP conformed/reporting, Layer 3 | Proposed downstream of CP refined | Optional reporting structures, deferred in the architecture. There is no evidenced CP raw → core → CP conform load in the numbered scripts. |

Conforming **values or organization data inside `core`** is a transformation
within refined; it does not mean that a separate CP reporting layer exists.

## 3. What is a schema? How to read names

A database **schema** is a namespace grouping related tables, views and other
objects. `schema.table` identifies a table within a PostgreSQL database.
For example:

```text
raw_gmdf_core_change_qms.mdm_qms_change_control
|-----------------------| |-------------------|
      raw schema               table
```

The upstream Redshift object is named
`gmdf_core_change_qms.mdm_qms_change_control`. The CP raw copy adds the
`raw_` prefix to distinguish it from the upstream product. A same-named table
in different schemas is **not automatically the same object**.

| Schema or prefix | Role | Example |
|---|---|---|
| `gmdf_core_deviation_qms`, `gmdf_core_change_qms`, `gmdf_core_aud_insp_qms` | Upstream GMDF quality-product schemas | `gmdf_core_change_qms.mdm_qms_change_control` |
| `raw_gmdf_core_deviation_qms`, `raw_gmdf_core_change_qms`, `raw_gmdf_core_aud_insp_qms`, `raw_gmdf_core_complaint_qms` | Local source-shaped raw tables separated by domain | `raw_gmdf_core_deviation_qms.mdm_qms_deviation` |
| `raw_gmdf_core_tpqm_qms`, `raw_gmdf_core` | Local third-party and supplier source data used in the scripts | `raw_gmdf_core_tpqm_qms.mdm_qms_external_party` |
| `core` | Refined application business entities | `core.cp_app_quality_events` |
| `ref` | Standardized codes, dimensions, aliases and configuration | `ref.event_status_alias`, `ref.partner_status` |
| `ops` | Load progress, batches and operational issues | `ops.load_batch`, `ops.load_watermark` |
| `rbac` | Users, roles and permissions | `rbac.users` |
| `audit` | Application audit, signatures and access records | `audit.audit_event` |

Names such as `core` inside `raw_gmdf_core_*` are inherited from the GMDF
source naming convention. They do **not** make those tables part of the CP
`core` schema. The source workbook lists complaints under `gmdf_core_qms`,
while the local scripts use `raw_gmdf_core_complaint_qms`. The architecture
also marks the published complaints schema as needing confirmation. Verify
the actual upstream-to-local mapping and grants rather than assuming a
mechanical prefix always determines the deployed name.

## 4. A load in time order

The following is the **architecture's intended flow**, followed by what the
files actually implement. The architecture is a future-state design, marked
work in progress and not yet signed off in the document.

1. **A business change occurs.** A source record is created or modified, for
   example a change-control event. Its source identifier and modification time
   are important for identity and incremental extraction.
2. **GMDF publishes/refreshes its product.** CP Management reads the governed
   Redshift product rather than directly calling each source system. The
   architecture describes several quality products refreshing at least four
   times a day; the proposed CP load cadence is nightly and marked for
   confirmation. The derived-platform workbook separately describes a
   four-hour `GMDF_DELTA_LOAD`. Neither is proof of the live schedule.
3. **A CP ingestion run extracts a delta.** The design uses a per-source-table
   watermark and a `last_modified_date` predicate. Initial loads and controlled
   backfills need their own agreed boundaries. A watermark is a progress
   marker, not a guarantee that every late or backdated update will be seen.
4. **Land in raw.** The architecture says to retain source columns as
   published, append versions, and attach `_load_batch_id`, `_ingested_at`,
   `_record_hash` and `_is_current`. It proposes reconciling counts and maximum
   modification time before accepting a batch. The numbered SQL reads
   `_is_current` and `_source_deleted`; the workspace does not contain a
   complete raw-ingestion implementation to validate these mechanics.
5. **Resolve and standardize into refined.** Read current raw records, remove
   duplicates at the appropriate grain, resolve organizations and partners,
   translate source vocabulary through `ref` aliases, and populate business
   tables. For example, an external status string becomes a reference ID.
6. **Apply the quality gates.** The design calls for an unresolved-key
   exception queue, reconciliation, idempotent reruns and protection of
   human-managed fields. Some supplied SQL instead filters unresolved rows,
   produces NULLs or uses fallbacks; do not assume those proposed gates are
   implemented end to end.
7. **Write refined data and record progress.** The intended load updates only
   source-owned fields and preserves application-entered information. Record
   batch outcome and advance the appropriate watermark only after success.
8. **Consume.** The app and its scorecard views read refined data. A separate
   CP reporting layer could later be built from refined data, but its tables,
   mapping, schedule and load are not specified here.

### A small example: one change record

The following IDs and times are illustrative, not actual data.

| Time | What happens | Example |
|---|---|---|
| 08:00 | A change is updated in its originating system. | Change ID `chg-42`, organization ID `org-10`, classification “Major”. |
| 09:00 | A refreshed GMDF product makes it available. | Upstream `gmdf_core_change_qms.mdm_qms_change_control`. |
| 10:00 | A successful extraction lands a source-shaped version. | `raw_gmdf_core_change_qms.mdm_qms_change_control` plus load metadata. |
| 10:05 | Refined processing maps organization and classification. | Lookup organization and `ref.event_classification_alias`, then populate `core.cp_app_quality_events`. |
| Later | A reviewer uses the refined event in a quarterly process. | Application and scorecard logic read refined entities and views. |
| Later still | The source changes again. | A subsequent load may close an old refined version and create another, if a tracked attribute differs. |

The design describes attribution through `core.cp_app_cp_org_map` and
`core.cp_app_quality_event_partner`. The checked-in `05` script instead
directly matches a level-2 organization ID to an active common-name
`source_org_id` and writes `core.cp_app_quality_events`; it does not implement
that complete attribution flow. The script assumes the record **number** as
`source_record_id`, while the architecture requires the stable EDB natural ID.
Confirm the key and attribution design before relying on that lineage.

## 5. CP, site and organization levels

**Do not confuse an organization hierarchy level with a data layer.**
“Layer 1 raw” describes where data is stored. “Level 1 organization” describes
a business hierarchy field in an event. They are unrelated numbering systems.

`core.cp_app_common_name` is the partner registry/anchor in the data model.
`cp_id` in related tables references a partner row. An **organization unit**
is a source organization in the GMDF hierarchy; not every organization is a
partner. A partner can relate to multiple source identifiers or organizations,
and an organization relationship may need a many-to-many mapping. A site,
plant or team is not automatically equivalent to a CP.

The source STTM workbook's **Level-1234** sheet provides these labels for
**deviation and change**:

| Source field | Workbook label | How the checked-in `05` quality-event script uses the ID |
|---|---|---|
| `level_1_organization_id` | Site | Not selected as an organization-unit ID in this script. |
| `level_2_organization_id` | Plant | Used for `plant_org_unit_id` and a direct, optional partner lookup. |
| `level_3_organization_id` | Process | Used for `flow_team_org_unit_id`; `04` also reads the level-3 organization's name as operation text for deviation/change. |
| `level_4_organization_id` | Flow | Used for `process_team_org_unit_id`. |

**Unresolved conflict:** The workbook labels level 3 “process” and level 4
“flow”, while the script and future-state model label level 3 as flow team and
level 4 as process team. The `trw_*` source-name fields and different domain
conventions also need verification. Do not silently swap or generalize these
labels; ask the GMDF data owner to confirm each source field and target meaning.
The workbook does not populate equivalent labels for ICI, audit or complaint.
Audit uses `level_*_auditee_id`, and complaints use
`responsible_organization_id` in the relevant mappings; their semantics must be
validated independently.

The data model proposes `core.cp_app_cp_org_map` for explicit partner-to-unit
attribution and `core.cp_app_cp_identifier` for external identifiers. Current
SQL shortcuts using `source_org_id` do not establish a universal one-to-one
partner mapping. For organization units the `03` script populates parents in
a second pass, with a maximum of 20 iterations; unresolved or removed parents
and deeper hierarchies need separate review.

## 6. The five checked-in raw-to-core loads

Each numbered script is PostgreSQL 15+ SQL. The ordering below is a **dependency
reading order**, not evidence of an installed scheduler. Reference data and
target schemas must already exist. Most scripts refer to a
`00_scd2_prerequisites.sql` file that is not present in this workspace.

| Script / target | What it prepares and its active business key | Main dependencies and cautions |
|---|---|---|
| [`01`](./01_cp_app_common_name.sql) `core.cp_app_common_name` | Partner registry; `source_org_id`. Uses third-party external parties and names from quality-domain organizations. | Requires mapped `ref.partner_status`; unmapped states and missing names are excluded. Existing app-managed name and certain flags/statuses are retained. Duplicate active names can be skipped. |
| [`02`](./02_cp_app_cp_detail.sql) `core.cp_app_cp_detail` | Partner site details; `(cp_id, site_name)`. Combines supplier addresses, external parties and organization records. | Needs active common-name rows and country aliases. Chooses among domains by priority and preserves app-managed address overrides and primary-site fields. |
| [`03`](./03_cp_app_organization_unit.sql) `core.cp_app_organization_unit` | Source organization units; `(external_system_id, source_org_id)`. Selects among domain copies and then links parents. | Reads common names and reference mappings. The parent pass has the limits described above. |
| [`04`](./04_cp_app_operations.sql) `core.cp_app_operations` | Partner operation group; `(cp_id, operation_group_id)`. Aggregates current deviation, change, audit and complaint records. | Needs active partner rows, aliases and operational tables. An unmatched alias falls back deterministically to an ID from 1–3; those IDs must exist and this is not evidence of a correct business mapping. |
| [`05`](./05_cp_app_quality_events.sql) `core.cp_app_quality_events` | Deviation, change and ICI events; `(external_system_id, source_record_id)`. | Reads active common names and organization units plus status/classification/quarter references. Record number is used as the assumed source ID; missing number or created date is excluded and unresolved partner/unit lookups may be NULL. |

All five scripts read current, non-deleted source records where the relevant
raw filters are present. They take a temporary source snapshot and use an
SCD2-style close-and-insert pattern. Only `04` has the documented consumer
checkpoint implementation described below; do not assume the others share it.
The source workbook lists additional raw-to-core queries, including complaints,
audit and event-partner tables, but there are no corresponding numbered
standalone scripts for all of them here.

## 7. Time, history, watermarks and SCD2

### Four kinds of time

| Time field/concept | Meaning | Do not confuse it with |
|---|---|---|
| Source created/modified time | When the source says a record was created or changed. | When CP Management loaded it. |
| Ingestion time | When a raw copy was landed, such as `_ingested_at` in the design. | The original event date. |
| Business effective dates | For example, `effective_from` / `effective_to` on an operation describe source/business data. | The SCD version's start and end. |
| SCD version timestamps | `effective_start_timestamp` and `effective_end_timestamp` describe a refined row version's validity in the load model. | A statement that the business event itself began at load time. |

**SCD Type 2** (slowly changing dimension type 2) keeps an old version when a
tracked value changes:

```text
business key        value       effective start      effective end       active
(CP 7, group 2)     old         10:00                14:00               false
(CP 7, group 2)     new         14:00                NULL                true
```

The example assumes half-open intervals `[start, end)`: at 14:00 the new row
applies, not both rows. A new business key is inserted, an unchanged one is
left alone, and a tracked change closes the old row and inserts a new one.
`active_flag` represents the current **version**; `is_active`, where present,
is a business/source status and is not interchangeable with it. An SCD row
may receive a new surrogate `id` for each version, so downstream foreign-key
and historical-reference behavior must be designed and verified.

### The operations consumer checkpoint (`04` only)

1. Lock `core.cp_app_operations` against concurrent writers and capture a
   fixed run cutoff.
2. Read the largest `watermark_to` from a completed `SUCCEEDED` batch for
   `GMDF` / `core.cp_app_operations`; use 1900-01-01 UTC on the first run.
   This is a **consumer checkpoint**, separate from raw ingestion watermarks.
3. Aggregate complete current source groups before selecting candidates.
   The lower boundary is inclusive for retry; future-dated groups are deferred.
   A previously unseen key can be inserted even if its timestamp is older than
   the lower boundary.
4. Reject duplicate active partner/group identities. Compare tracked fields;
   an older source timestamp cannot close a newer active target version.
5. Close changed versions, insert replacements, and record the successful batch
   and watermark in one transaction. Failure rolls back target and progress;
   the runner must report the error and separately record a failed-run audit.

The checkpoint relies on source timestamps representing committed, visible
changes. Backdated arrivals need controlled replay; deletes, mapping-only
corrections and identity changes need reconciliation. `04` creates a partial
unique index for active `(cp_id, operation_group_id)` rows. The
[`README`](./README.md) contains execution prerequisites and the disposable
database regression-test command.

## 8. How to investigate a number or failed load

1. Start with the business question: partner, event, quarter and expected
   output. Capture the relevant source ID and external system, not just a
   human-readable name.
2. Identify the refined `core` row and, if looking for current data, its
   `active_flag`. Inspect the historical versions too when investigating
   changes over time.
3. Check partner and organization attribution, including whether direct
   `source_org_id` matching or the proposed mapping table was actually used.
4. Follow the source ID to the relevant raw domain and source record; inspect
   current/deleted indicators and source timestamps. Do not assume that
   quality-event `source_record_id` is the natural ID until the `05` key
   discrepancy is resolved.
5. Check reference aliases, status and classification mappings, and quarterly
   date boundaries. A missing alias, required status or partner can change
   whether a row loads or links.
6. Inspect `ops.load_batch`, `ops.load_watermark` and, **if implemented and
   populated**, `ops.data_quality_issue`. For `04`, scope progress to the
   `GMDF` / `core.cp_app_operations` consumer, not a raw-source watermark.
7. Compare source and raw counts, duplicates, freshness and rejected records.
   Escalate unresolved mappings or missing data; do not silently infer them.
   Any replay should follow the team's approved operating procedure.

The source workbook contains snapshot load/count annotations, including a
complaint load filtered to non-null responsible organizations. Those entries
are historical workbook observations, not proof of current completeness or of
the architecture's proposed unfiltered raw behavior.

## 9. Abbreviations and common column conventions

| Term | Meaning in this project |
|---|---|
| CP | Collaboration Partner. |
| CP ID / `cp_id` | Identifier linking a row to the CP registry; legacy variants include CPID, IDFK and CPIDFK. Verify the actual key and version semantics. |
| PR&D | The quality/business area named in the architecture; confirm its formal expansion with the business. |
| GMDF | Global Manufacturing Data Foundation, the upstream data products. |
| EDB | The enterprise data platform/layer named by the architecture; its exact expansion is not established in the inspected glossary. |
| QMS | Quality Management System. `QMS_VEEVA` is an external-system reference code used in the scripts. |
| TPQM | Third-party quality domain. The full formal expansion is not established in the inspected files. |
| MDM | Master Data Management; appears in source table prefixes such as `mdm_qms_organization`. Verify the publisher's exact table semantics. |
| STTM | Source-to-target mapping: a workbook documenting where target columns come from and how they are derived. |
| ETL | Extract, transform, load: move and transform data from source to target. |
| SCD2 | Slowly changing dimension, Type 2: retain a history of versions. |
| PK / FK | Primary key identifies a row; foreign key references a row in another table. |
| Business/natural key | Source or business identifier used to recognize the same logical entity across loads; its exact columns are table-specific. |
| Surrogate key | An application/database-generated row identifier, such as an identity `id`; it is not necessarily the source ID. |
| `source_org_id` | Source organization identifier, not inherently the application's `cp_id`. |
| `external_system_id` | Reference ID identifying the originating external system. |
| `source_record_id` | Source-side record identity carried into refined; actual `05` uses a record number as an assumption, contrary to the architecture's natural-ID requirement. |
| `src` / `tgt` | SQL aliases for source and target. |
| `ref` / alias | Standard vocabulary/reference data / a mapping from a source value to a standard value. |
| `ops` | Operational tables for jobs, watermarks, issues and integration. |
| `rbac` | Role-based access control. |
| ICI | Intra Company Issue, a quality-record class. |
| CAPA | Corrective and Preventive Action. |
| NTM | Notification To Management. |
| QNF | Quality Notification Form. |
| QPR | Quarterly Performance Report. |
| PIP | Person-in-Plant: a scheduled on-site partner visit. |
| TPO | An onboarding source mentioned in the architecture; expansion not confirmed there. |
| MP number | Partner identifier derived by EDB from the Veeva vendor number; exposure/availability requires confirmation. |
| DQ | Data quality. |
| Delta | Only records selected as changed since a progress boundary, not necessarily every record. |
| Watermark | Persisted boundary tracking extraction or consumer progress; each consumer/source needs the correct scope. |
| Idempotency | Repeating a load with the same inputs does not create unintended additional changes. |
| `rn` / `row_number()` | Ranking used to select a candidate per partition; equal sort values may require a deterministic tie-breaker. |
| `NULL` | Missing/unknown/not applicable value in SQL; the reason depends on the field. |
| DDL | Data definition language, such as `CREATE TABLE`; distinct from the SQL that loads rows. |
| UI | User interface; UI-managed values are entered or maintained by people, not overwritten blindly by source loads. |

## 10. Open questions for the team

- Which schedule and orchestration platform actually run each production job?
  Is Temporal used at all? Reconcile nightly versus the four-hour workbook job.
- Confirm level 3/process versus level 3/flow and the equivalent level-4
  meaning for each source and target field.
- What are the approved upstream complaint schema, permissions, raw mapping
  and extraction/filter rules? Is raw intended to be a complete replica?
- What is the approved stable natural key for each quality-event type? Resolve
  the architecture versus `05` record-number discrepancy and collision risks.
- How are partners, sites and multiple organizations matched and approved?
  When will `cp_app_cp_org_map` and event-partner attribution be populated?
- Where are unresolved records, missing aliases, deletions, late arrivals and
  mapping-only changes recorded and replayed? Verify actual behavior rather
  than assuming the design's exception gates exist.
- Where are the SCD2 prerequisites and constraints? How do downstream foreign
  keys remain valid when a partner or organization gets a new version?
- Are CP-specific reporting tables needed? If so, define their grain, source,
  owner, refresh schedule and reconciliation before calling that layer built.

## 11. Where this guide comes from

- [Solution Architecture Document v2.2](<./CP_Management_Solution_Architecture_Document_v2_2.docx>):
  sections 7.1–7.3, 8 and 15.1; the intended data flow, layers and glossary.
- [Future-State Data Model v3.2](<./CP_Management_Future_State_Data_Model_v3_2.docx>):
  entity meanings, hierarchy and proposed partner mapping.
- [Source STTM V6](<./CP_Management_App_STTMs_Source_V6 (3).xlsx>):
  **GMDF Source Tables**, **Domain-Summary**, **Level-1234** and **Raw-to-Core**
  sheets; column-level source mappings and workbook observations.
- [Derived/platform STTM](<./CP_Management_App_STTMs_ETL_Derived_Platform_System_v3_5_1_v2 (2).xlsx>)
  and [data provenance](./data-provenance.md): application-derived entities
  and operational table descriptions.
- [README](./README.md) and [numbered operations SQL](./04_cp_app_operations.sql):
  actual operations-load checkpoints, prerequisites and verification.

Where design documents, workbook mappings and checked-in scripts differ, this
guide calls out the difference. Confirm deployed database objects, job
configuration and approved business definitions before making operational
decisions.
