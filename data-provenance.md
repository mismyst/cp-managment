# Data provenance - Derived Platform System

## Scope and interpretation

- Source workbook: `CP_Management_App_STTMs_ETL_Derived_Platform_System_v3_5_1_v2 (2).xlsx`.
- This workbook contains **29 table-load definitions**. Eleven entity tabs document per-column types, keys, source fields, and transformation logic; the remaining 18 tables have load-query column lists but no corresponding per-column STTM tab.
- The workbook states that these are derived-in-app, platform/identity, audit, or pipeline entities; legacy tables are lineage context only, **not direct sources**. The SQL references below are extracted from the workbook load queries and do not imply legacy-source ingestion.
- Identity columns are listed where the workbook says they are generated; generated `id` fields are omitted from INSERT column lists. The `rbac.role_permissions` load lists two columns and has no generated `id`. For tables without a detailed entity tab, data types and column-level transformations are not specified here.
- The workbook notes that the SQL was not executed because no PostgreSQL instance was available. Treat this as documented lineage/design, not proof of a successful production load.

## Table inventory

### `core.cp_app_cp_status_history`

**Purpose:** Builds the history of every status a partner has had. One row = one period: which status, from when, until when (empty = still valid) and why it changed.

**Population / load mode:** IN-APP DERIVATION: opening row, source sync (open items SOI-20, SOI-21, SOI-22, SOI-24).

**Referenced source relations:** `core.cp_app_common_name`, `ref.partner_status`, `ref.status_change_trigger`.

**Columns:** `id` (bigint) - PK; `cp_id` (bigint) - FK → core.cp_app_common_name; `partner_status_id` (integer) - FK → ref.partner_status; `status_change_trigger_id` (integer) - FK → ref.status_change_trigger; `effective_from` (timestamptz); `effective_to` (timestamptz); `reason` (varchar(1000)); `created_at` (timestamptz); `created_by_user_id` (bigint) - FK → rbac.users; `updated_at` (timestamptz); `updated_by_user_id` (bigint) - FK → rbac.users; `row_version` (integer).
**Specially formed columns:** `id` - Generated: identity; `status_change_trigger_id` - Lookup (ref.status_change_trigger): 'MIGRATION' \| Lookup: 'SOURCE_SYNC'; `effective_from` - Join ps + CASE: ACTIVE -> active_since_date, else created_at \| Function: now(); `effective_to` - Function: lead(effective_from) OVER (PARTITION BY cp_id ORDER BY effective_from); `reason` - Join ps + concat: 'text' \|\| ps.name \| Join ps + concat: 'text' \|\| ps.name; `created_at` - Function: now(); `created_by_user_id` - Constant: NULL; `updated_at` - Constant: NULL; `updated_by_user_id` - Constant: NULL; `row_version` - Constant: 1.

### `core.qpr`

**Purpose:** Creates the quarterly scorecard (QPR) of every partner-quarter that already has quarterly data in the app. One row = one partner in one quarter.

**Population / load mode:** IN-APP DERIVATION.

**Referenced source relations:** `core.cp_app_assessment_status`, `core.cp_app_common_name`, `core.cp_app_complaint_partner`, `core.cp_app_cp_activity`, `core.cp_app_cp_contact`, `core.cp_app_ntm`, `core.cp_app_qnf`, `core.cp_app_summary`, `ref.contact_role`, `ref.cp_app_qtr_table`, `ref.partner_status`, `ref.scorecard_status`.

**Inputs:** `:quarter_id`.

**Columns:** `id` (bigint) - PK; `cp_id` (bigint) - FK → core.cp_app_common_name; `quarter_id` (integer) - FK → ref.cp_app_qtr_table; `scorecard_status_id` (integer) - FK → ref.scorecard_status; `qual_rep_user_id` (bigint) - FK → rbac.users; `due_date` (date); `is_blocked_on_hold` (boolean); `reminder_sent_at` (timestamptz); `escalated_at` (timestamptz); `submitted_at` (timestamptz); `submitted_by_user_id` (bigint) - FK → rbac.users; `completed_at` (timestamptz); `created_at` (timestamptz); `created_by_user_id` (bigint) - FK → rbac.users; `updated_at` (timestamptz); `updated_by_user_id` (bigint) - FK → rbac.users; `row_version` (integer).
**Specially formed columns:** `id` - Generated: identity; `scorecard_status_id` - Lookup (ref.scorecard_status): 'NOT_STARTED'; `qual_rep_user_id` - Subquery: c.user_id of the primary open contact with role 'QUAL_REP'; `due_date` - Function: date_trunc('month', end_date + 1) + 1 month - 1 day; `is_blocked_on_hold` - Join ref.partner_status: NOT ps.is_reviewable; `reminder_sent_at` - Constant: NULL; `escalated_at` - Constant: NULL; `submitted_at` - Constant: NULL; `submitted_by_user_id` - Constant: NULL; `completed_at` - Constant: NULL; `created_at` - Function: now(); `created_by_user_id` - Constant: NULL; `updated_at` - Constant: NULL; `updated_by_user_id` - Constant: NULL; `row_version` - Constant: 1.

### `core.cp_app_risk_metrics`

**Purpose:** Creates the rating rows of one scorecard (parameter :qpr_id): one row for each operation of the partner. The band and the SME confirmation are filled by later steps.

**Population / load mode:** IN-APP DERIVATION.

**Referenced source relations:** `core.qpr`, `ref.cp_app_qtr_table`, `ref.rating_status`, `core.cp_app_site_visits`, `core.cp_app_operations`, `ref.risk_band`, `core.cp_app_risk_criterion_result`, `ref.risk_criterion`.

**Inputs:** `:qpr_id`, `:risk_metric_id`, `:final_band_code`, `:rationale_text`, `:mitigation_text`, `:acting_user_id`.

**Columns (21 total, names from load SQL):** `id` (generated identity); `qpr_id`; `operation_id`; `computed_band_id`; `final_band_id`; `prior_band_id`; `rating_status_id`; `rationale_text`; `mitigation_text`; `last_pip_date`; `legacy_last_pip_text`; `scored_by_user_id`; `scored_at`; `computed_at`; `is_baseline`; `sent_to_qdocs_at`; `created_at`; `created_by_user_id`; `updated_at`; `updated_by_user_id`; `row_version`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.cp_app_risk_criterion_result`

**Purpose:** Stores the outcome of one decision-matrix criterion for one rating. One row = one criterion checked.

**Population / load mode:** RULE ENGINE / SME.

**Referenced source relations:** `ref.risk_criterion`, `core.cp_app_risk_metrics`.

**Inputs:** `:observed_value`, `:risk_metric_id`, `:criterion_code`, `:is_met`, `:is_system_evaluated`, `:evidence_note`, `:evaluator_user_id`.

**Columns (9 total, names from load SQL):** `id` (generated identity); `risk_metric_id`; `risk_criterion_id`; `is_met`; `observed_value`; `is_system_evaluated`; `evidence_note`; `evaluated_by_user_id`; `evaluated_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.cp_app_score_adjustment`

**Purpose:** Records one automatic change of a partner's score. Append-only: rows are never changed.

**Population / load mode:** RULE ENGINE (append-only).

**Referenced source relations:** `ref.score_rule`.

**Inputs:** `:cp_id`, `:qpr_id`, `:score_rule_code`, `:quality_event_id`, `:is_data_correction`, `:alert_id`.

**Columns (9 total, names from load SQL):** `id` (generated identity); `cp_id`; `qpr_id`; `score_rule_id`; `quality_event_id`; `score_delta`; `is_data_correction`; `alert_id`; `applied_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.qpr_report_partner`

**Purpose:** Links a generated QPR report to the scorecards it covers. One row = one scorecard in one report.

**Population / load mode:** REPORT GENERATION.

**Referenced source relations:** `core.qpr_report`, `ref.report_scope`, `ref.cp_app_qtr_table`, `core.qpr`, `core.cp_app_operations`.

**Inputs:** `:qpr_report_id`.

**Columns (3 total, names from load SQL):** `id` (generated identity); `qpr_report_id`; `qpr_id`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.qpr_report_version`

**Purpose:** Registers a newly generated report file as a new version of a report. One row = one generated file.

**Population / load mode:** BACKEND REPORT GENERATION (replaces Power Automate flow QPRReportV2t).

**Referenced source relations:** `ref.file_format`, `core.qpr_report`.

**Inputs:** `:qpr_report_id`, `:storage_uri`, `:sha256`, `:acting_user_id`.

**Columns (11 total, names from load SQL):** `id` (generated identity); `qpr_report_id`; `version_no`; `file_format_id`; `storage_uri`; `sha256`; `generated_at`; `generated_by_user_id`; `reviewed_by_user_id`; `reviewed_at`; `is_current`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.approval_request`

**Purpose:** Opens an approval process for one object (a QPR report, a PIP visit, a rating, a qualification or a summary). One row = one approval.

**Population / load mode:** APPROVAL WORKFLOW.

**Referenced source relations:** `ref.approval_status`, `ref.approval_purpose`, `ref.approval_chain_template`, `ref.external_system`.

**Inputs:** `:approval_purpose_code`, `:qpr_report_id`, `:site_visit_id`, `:risk_metric_id`, `:cp_qualification_id`, `:summary_id`, `:system_of_record_code`, `:external_reference`, `:deadline`, `:acting_user_id`.

**Columns (20 total, names from load SQL):** `id` (generated identity); `approval_purpose_id`; `approval_chain_template_id`; `qpr_report_id`; `site_visit_id`; `risk_metric_id`; `cp_qualification_id`; `summary_id`; `approval_status_id`; `system_of_record_id`; `external_reference`; `submitted_by_user_id`; `submitted_at`; `deadline`; `completed_at`; `created_at`; `created_by_user_id`; `updated_at`; `updated_by_user_id`; `row_version`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.cp_app_report_comments_bu`

**Purpose:** Takes a frozen snapshot of a scorecard's counts each time its workflow moves (submit, approve, return). Insert-only.

**Population / load mode:** SNAPSHOT at each QPR workflow transition (insert-only).

**Referenced source relations:** `core.cp_app_complaint_partner`, `core.cp_app_ntm`, `core.v_overdue_actions`, `ref.action_category`, `core.cp_app_qnf`, `ref.document_status`, `core.cp_app_capa`, `ref.event_status`, `core.cp_app_risk_metrics`, `core.cp_app_assessment_status`, `core.qpr`, `ref.cp_app_qtr_table`, `core.v_qpr_basic_metrics`.

**Inputs:** `:qpr_id`, `:audit_event_id`.

**Columns (15 total, names from load SQL):** `id` (generated identity); `qpr_id`; `snapshot_at`; `audit_event_id`; `major_count`; `moderate_count`; `minor_count`; `change_count`; `ici_count`; `complaint_count`; `ntm_count`; `overdue_audit_action_count`; `open_qnf_count`; `significant_capa_count`; `payload`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.agent_run`

**Purpose:** Logs the start of one AI agent run. One row = one run.

**Population / load mode:** AI AGENT ORCHESTRATION.

**Referenced source relations:** `ref.agent_task_type`, `ref.run_status`.

**Inputs:** `:agent_task_type_code`, `:qpr_id`, `:qpr_report_id`, `:acting_user_id`, `:model_name`, `:prompt_template_version`, `:run_status_code`, `:input_tokens`, `:output_tokens`, `:error_message`, `:agent_run_id`.

**Columns:** `id` (bigint) - PK; `agent_task_type_id` (integer) - FK → ref.agent_task_type; `qpr_id` (bigint) - FK → core.qpr; `qpr_report_id` (bigint) - FK → core.qpr_report; `requested_by_user_id` (bigint) - FK → rbac.users; `run_status_id` (integer) - FK → ref.run_status; `started_at` (timestamptz); `completed_at` (timestamptz); `model_name` (varchar(100)); `prompt_template_version` (varchar(30)); `input_tokens` (integer); `output_tokens` (integer); `error_message` (varchar(2000)).
**Specially formed columns:** `id` - Generated: identity; `run_status_id` - Lookup (ref.run_status): 'RUNNING'; `started_at` - Function: now(); `completed_at` - Constant: NULL; `input_tokens` - Constant: NULL; `output_tokens` - Constant: NULL; `error_message` - Constant: NULL.

### `core.agent_run_source`

**Purpose:** Records one source record that an AI agent read for its draft. One row = one record cited.

**Population / load mode:** AI AGENT ORCHESTRATION.

**Referenced source relations:** `ref.entity_type`.

**Inputs:** `:agent_run_id`, `:entity_type_code`, `:entity_record_id`, `:source_label`.

**Columns:** `id` (bigint) - PK; `agent_run_id` (bigint) - FK → core.agent_run; `entity_type_id` (integer) - FK → ref.entity_type; `entity_record_id` (bigint); `source_label` (varchar(255)).
**Specially formed columns:** `id` - Generated: identity.

### `core.cp_app_alert`

**Purpose:** Raises alerts from six rules. One row = one alert for one partner (and one object).

**Population / load mode:** RULE ENGINE (job ALERT_EVALUATION hourly and the rule jobs).

**Referenced source relations:** `core.v_quality_agreement_expiry`, `core.cp_app_site_visits`, `ref.alert_rule`, `core.qpr`, `ref.scorecard_status`, `core.v_cp_inactivity`, `ref.alert_status`, `c.qpr_id`, `c.quality_agreement_id`, `c.site_visit_id`.

**Columns (19 total, names from load SQL):** `id` (generated identity); `alert_rule_id`; `alert_category_id`; `severity_level_id`; `cp_id`; `qpr_id`; `quality_event_id`; `quality_agreement_id`; `site_visit_id`; `risk_metric_id`; `regulatory_log_id`; `message`; `raised_at`; `alert_status_id`; `acknowledged_by_user_id`; `acknowledged_at`; `escalated_to_user_id`; `escalated_at`; `resolved_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `core.cp_app_notification`

**Purpose:** Queues the messages that tell people about an alert. One row = one recipient and one channel.

**Population / load mode:** NOTIFICATION SERVICE.

**Referenced source relations:** `ref.notification_type`, `ref.delivery_status`, `core.cp_app_alert`, `ref.alert_category`, `core.cp_app_common_name`, `core.cp_app_alert_subscription`, `ref.notification_channel`, `core.review_task`.

**Inputs:** `:alert_id`, `:review_task_id`.

**Columns (14 total, names from load SQL):** `id` (generated identity); `alert_id`; `review_task_id`; `recipient_user_id`; `notification_type_id`; `notification_channel_id`; `subject`; `body`; `delivery_status_id`; `queued_at`; `sent_at`; `read_at`; `failure_reason`; `external_message_id`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.users`

**Purpose:** Creates or refreshes the app's users from the identity provider (Entra ID). One row = one person.

**Population / load mode:** IDENTITY PROVIDER SYNC (job ENTRA_RECONCILIATION, nightly).

**Referenced source relations:** No qualified table references were detected in the load SQL; population is by application input, seed data, system process, or an unqualified query source. See the workbook query.

**Inputs:** `:entra_directory`, `:entra_oid`, `:email`, `:full_name`, `:entra_active_oids`.

**Columns (8 total, names from load SQL):** `id` (generated identity); `entra_oid`; `email`; `full_name`; `is_active`; `created_at`; `updated_at`; `last_login_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.roles`

**Purpose:** Loads the seven roles of the app from the DDL seed list. One row = one role.

**Population / load mode:** SEED DATA from the DDL (7 roles).

**Referenced source relations:** No qualified table references were detected in the load SQL; population is by application input, seed data, system process, or an unqualified query source. See the workbook query.

**Columns (3 total, names from load SQL):** `id` (generated identity); `role_name`; `description`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.permissions`

**Purpose:** Loads the permission keys (business actions) from the DDL seed list. One row = one permission.

**Population / load mode:** SEED DATA from the DDL (22 permission keys).

**Referenced source relations:** No qualified table references were detected in the load SQL; population is by application input, seed data, system process, or an unqualified query source. See the workbook query.

**Columns (3 total, names from load SQL):** `id` (generated identity); `permission_key`; `description`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.role_permissions`

**Purpose:** Loads the role-permission matrix from the DDL seed list: which role may do which action. One row = one pair.

**Population / load mode:** SEED DATA from the DDL (role-permission matrix, 60 pairs).

**Referenced source relations:** `rbac.roles`, `rbac.permissions`.

**Columns (2 total, names from load SQL):** `role_id`; `permission_id`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.user_role_partner`

**Purpose:** Gives a user a role for ONE partner (optionally one operation group). One row = one assignment.

**Population / load mode:** ADMIN ACTION (user access management).

**Referenced source relations:** `rbac.users`, `rbac.roles`, `core.cp_app_common_name`, `ref.operation_group`, `core.cp_app_cp_contact`, `ref.contact_role`.

**Inputs:** `:user_id`, `:role_name`, `:partner_id`, `:operation_group_code`, `:effective_from`, `:effective_to`, `:acting_user_id`.

**Columns (9 total, names from load SQL):** `id` (generated identity); `user_id`; `role_id`; `partner_id`; `operation_group_id`; `effective_from`; `effective_to`; `granted_by_user_id`; `granted_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `rbac.user_role_global`

**Purpose:** Gives a user a role that applies to ALL partners (ADMIN, QUALITY_LEADERSHIP, DATA_OWNER). One row = one assignment.

**Population / load mode:** ADMIN ACTION.

**Referenced source relations:** `rbac.users`, `rbac.roles`.

**Inputs:** `:user_id`, `:role_name`, `:effective_from`, `:effective_to`, `:acting_user_id`.

**Columns (7 total, names from load SQL):** `id` (generated identity); `user_id`; `role_id`; `effective_from`; `effective_to`; `granted_by_user_id`; `granted_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `audit.audit_event`

**Purpose:** Writes one tamper-evident audit event. One row = one action (who did what, to which record, when, why). Rows are never changed.

**Population / load mode:** AUDIT SERVICE (insert-only, hash-chained).

**Referenced source relations:** `ref.actor_type`, `ref.audit_action`, `ref.entity_type`.

**Inputs:** `:actor_type_code`, `:actor_user_id`, `:audit_action_code`, `:entity_type_code`, `:entity_record_id`, `:cp_id`, `:reason_text`, `:correlation_id`, `:session_id`, `:client_ip`, `:source_component`.

**Columns:** `id` (bigint) - PK; `occurred_at` (timestamptz); `actor_type_id` (integer) - FK → ref.actor_type; `actor_user_id` (bigint) - FK → rbac.users; `audit_action_id` (integer) - FK → ref.audit_action; `entity_type_id` (integer) - FK → ref.entity_type; `entity_record_id` (bigint); `cp_id` (bigint) - FK → core.cp_app_common_name; `reason_text` (varchar(2000)); `correlation_id` (uuid); `session_id` (varchar(100)); `client_ip` (inet); `source_component` (varchar(50)); `prev_hash` (char(64)); `row_hash` (char(64)).
**Specially formed columns:** `id` - Generated: identity; `occurred_at` - Function: now(); `actor_type_id` - Lookup (ref.actor_type) by :actor_type_code; `audit_action_id` - Lookup (ref.audit_action) by :audit_action_code; `entity_type_id` - Lookup (ref.entity_type) by :entity_type_code; `prev_hash` - Subquery: row_hash of the latest audit_event; `row_hash` - Function: encode(digest(concat_ws('\|', event fields, prev_hash), 'sha256'), 'hex').

### `audit.audit_event_change`

**Purpose:** Stores the field-level changes of an audit event. One row = one field that changed.

**Population / load mode:** AUDIT SERVICE.

**Referenced source relations:** `o.value`.

**Inputs:** `:audit_event_id`, `:new_row`, `:old_row`.

**Columns:** `id` (bigint) - PK; `audit_event_id` (bigint) - FK → audit.audit_event; `column_name` (varchar(100)); `old_value` (text); `new_value` (text).
**Specially formed columns:** `id` - Generated: identity; `old_value` - Join (LEFT) old row image: o.value.

### `audit.e_signature`

**Purpose:** Records an electronic signature (21 CFR Part 11). One row = one signature on one approval step.

**Population / load mode:** SIGNING SERVICE (21 CFR Part 11).

**Referenced source relations:** `ref.signature_meaning`, `ref.entity_type`.

**Inputs:** `:user_id`, `:signature_meaning_code`, `:review_task_id`, `:auth_method`, `:auth_reference`, `:audit_event_id`.

**Columns (9 total, names from load SQL):** `id` (generated identity); `user_id`; `signature_meaning_id`; `signed_at`; `entity_type_id`; `entity_record_id`; `auth_method`; `auth_reference`; `audit_event_id`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `audit.access_log`

**Purpose:** Logs sign-in and access events. One row = one event (login, logout, timeout, denial ...).

**Population / load mode:** AUTHENTICATION / AUTHORISATION LAYER.

**Referenced source relations:** `rbac.permissions`, `ref.access_event_type`.

**Inputs:** `:event_type_code`, `:user_id`, `:entra_oid`, `:permission_key`, `:cp_id`, `:client_ip`, `:user_agent`, `:correlation_id`, `:detail`.

**Columns:** `id` (bigint) - PK; `occurred_at` (timestamptz); `access_event_type_id` (integer) - FK → ref.access_event_type; `user_id` (bigint) - FK → rbac.users; `entra_oid` (char(36)); `permission_id` (bigint) - FK → rbac.permissions; `cp_id` (bigint) - FK → core.cp_app_common_name; `client_ip` (inet); `user_agent` (varchar(500)); `correlation_id` (uuid); `detail` (varchar(1000)).
**Specially formed columns:** `id` - Generated: identity; `occurred_at` - Function: now(); `permission_id` - Join rbac.permissions: perm.id.

### `audit.data_export_log`

**Purpose:** Logs every export or report download. One row = one export.

**Population / load mode:** EXPORT / DOWNLOAD SERVICE.

**Referenced source relations:** `ref.export_type`.

**Inputs:** `:acting_user_id`, `:export_type_code`, `:qpr_report_version_id`, `:filter_criteria`, `:row_count`, `:sha256`.

**Columns:** `id` (bigint) - PK; `user_id` (bigint) - FK → rbac.users; `exported_at` (timestamptz); `export_type_id` (integer) - FK → ref.export_type; `qpr_report_version_id` (bigint) - FK → core.qpr_report_version; `filter_criteria` (jsonb); `row_count` (integer); `sha256` (char(64)).
**Specially formed columns:** `id` - Generated: identity; `exported_at` - Function: now().

### `ops.load_batch`

**Purpose:** Logs the start of a data load of one source table. One row = one load run of one source object.

**Population / load mode:** PIPELINE (job GMDF_DELTA_LOAD, every 4 hours).

**Referenced source relations:** `ops.load_watermark`, `ref.external_system`, `ref.run_status`.

**Inputs:** `:external_system_code`, `:source_object`, `:run_status_code`, `:watermark_to`, `:rows_read`, `:rows_inserted`, `:rows_updated`, `:rows_rejected`, `:error_message`, `:load_batch_id`.

**Columns:** `id` (bigint) - PK; `external_system_id` (integer) - FK → ref.external_system; `source_object` (varchar(200)); `run_status_id` (integer) - FK → ref.run_status; `started_at` (timestamptz); `completed_at` (timestamptz); `watermark_from` (timestamptz); `watermark_to` (timestamptz); `rows_read` (integer); `rows_inserted` (integer); `rows_updated` (integer); `rows_rejected` (integer); `error_message` (varchar(4000)).
**Specially formed columns:** `id` - Generated: identity; `run_status_id` - Lookup (ref.run_status): 'RUNNING'; `started_at` - Function: now(); `completed_at` - Constant: NULL; `watermark_from` - Join ops.load_watermark: w.watermark_value; `watermark_to` - Constant: NULL; `rows_read` - Constant: NULL; `rows_inserted` - Constant: NULL; `rows_updated` - Constant: NULL; `rows_rejected` - Constant: NULL; `error_message` - Constant: NULL.

### `ops.load_watermark`

**Purpose:** Remembers how far each source table has been loaded. One row = one source object.

**Population / load mode:** PIPELINE.

**Referenced source relations:** `ops.load_batch`, `ref.run_status`.

**Inputs:** `:load_batch_id`.

**Columns:** `id` (bigint) - PK; `external_system_id` (integer) - FK → ref.external_system; `source_object` (varchar(200)); `watermark_value` (timestamptz); `updated_at` (timestamptz).
**Specially formed columns:** `id` - Generated: identity; `updated_at` - Function: now().

`04_cp_app_operations.sql` owns a separate `GMDF` / `core.cp_app_operations` consumer checkpoint. It reads the last completed `SUCCEEDED` batch's `watermark_to` as its lower boundary (1900 on first run), captures a fixed upper boundary after locking the target, and writes its successful batch and watermark atomically with the target changes. Raw-ingestion checkpoints are not reused. Full current groups are aggregated before applying the window; the active identity is `(cp_id, operation_group_id)`, with `effective_from` tracked as an attribute. Backdated arrivals, deletions and mapping-only changes need separate replay/reconciliation.

### `ops.data_quality_issue`

**Purpose:** Puts a data problem found by the pipeline into the exception queue. One row = one problem on one record.

**Population / load mode:** PIPELINE.

**Referenced source relations:** `ref.flag_status`, `ref.dq_rule`.

**Inputs:** `:dq_rule_code`, `:load_batch_id`, `:source_object`, `:source_record_key`, `:issue_detail`.

**Columns (11 total, names from load SQL):** `id` (generated identity); `load_batch_id`; `dq_rule_id`; `severity_level_id`; `source_object`; `source_record_key`; `issue_detail`; `flag_status_id`; `raised_at`; `resolved_by_user_id`; `resolved_at`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

### `ops.job_run`

**Purpose:** Logs one execution of a scheduled job. One row = one run.

**Population / load mode:** SCHEDULER.

**Referenced source relations:** `ref.job_definition`, `ref.run_status`.

**Inputs:** `:job_code`, `:run_status_code`, `:items_processed`, `:error_message`, `:job_run_id`.

**Columns:** `id` (bigint) - PK; `job_definition_id` (integer) - FK → ref.job_definition; `run_status_id` (integer) - FK → ref.run_status; `started_at` (timestamptz); `completed_at` (timestamptz); `items_processed` (integer); `error_message` (varchar(4000)).
**Specially formed columns:** `id` - Generated: identity; `run_status_id` - Lookup (ref.run_status): 'RUNNING'; `started_at` - Function: now(); `completed_at` - Constant: NULL; `items_processed` - Constant: NULL; `error_message` - Constant: NULL.

### `ops.outbound_notification`

**Purpose:** Queues a message to each downstream system when a partner's status changes. One row = one message to one system.

**Population / load mode:** DOWNSTREAM NOTIFIER (job DOWNSTREAM_NOTIFY, every 5 minutes).

**Referenced source relations:** `ref.delivery_status`, `core.cp_app_cp_status_history`, `core.cp_app_common_name`, `ref.partner_status`, `ref.downstream_subscription`.

**Inputs:** `:cp_status_history_id`, `:delivery_status_code`, `:confirmed`, `:response_code`, `:response_body`, `:outbound_notification_id`.

**Columns (12 total, names from load SQL):** `id` (generated identity); `downstream_subscription_id`; `cp_id`; `cp_status_history_id`; `payload`; `delivery_status_id`; `created_at`; `attempt_count`; `last_attempt_at`; `delivery_confirmed_at`; `response_code`; `response_body`.
**Specially formed columns:** The workbook does not provide a per-column transformation map for this table; consult its full `Table Queries` SQL and explanation before treating any derived expression as a column-level rule.

## Workbook notes

- The entity-tab `Column Query` and `Source Tables` fields are the primary per-column lineage evidence where those tabs exist. The table-query SQL is the primary population evidence for every listed table.
- The source workbook also contains reference-code seeds, rule catalogue entries, open items, and legacy-lineage notes; they are contextual and are not expanded into separate tables in this inventory.
