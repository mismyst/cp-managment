-- Run only against an empty disposable PostgreSQL 15+ database:
-- psql -X -v ON_ERROR_STOP=1 -d <disposable_database> -f tests/04_cp_app_operations.sql
\set ON_ERROR_STOP on

create schema core;
create schema ref;
create schema ops;
create schema raw_gmdf_core_deviation_qms;
create schema raw_gmdf_core_change_qms;
create schema raw_gmdf_core_aud_insp_qms;
create schema raw_gmdf_core_complaint_qms;

create table ref.external_system (id integer primary key, code text unique);
create table ref.run_status (id integer primary key, code text unique);
create table ref.operation_group_alias (
    external_system_id integer, alias_value text, operation_group_id integer);
insert into ref.external_system values (1, 'GMDF'), (2, 'QMS_VEEVA');
insert into ref.run_status values (1, 'RUNNING'), (2, 'SUCCEEDED'), (3, 'FAILED');
insert into ref.operation_group_alias values (2, 'Manufacturing', 1);

create table ops.load_batch (
    id bigint generated always as identity primary key,
    external_system_id integer, source_object text, run_status_id integer,
    started_at timestamptz, completed_at timestamptz,
    watermark_from timestamptz, watermark_to timestamptz,
    rows_read integer, rows_inserted integer, rows_updated integer, rows_rejected integer,
    error_message text);
create table ops.load_watermark (
    external_system_id integer, source_object text,
    watermark_value timestamptz, updated_at timestamptz,
    unique (external_system_id, source_object));
create table core.cp_app_common_name (
    id bigint primary key, source_org_id text, active_flag boolean,
    effective_start_timestamp timestamptz);
create table core.cp_app_operations (
    id bigint generated always as identity primary key,
    cp_id bigint not null, operation_group_id integer not null,
    effective_from date not null, effective_to date,
    source_org_id text, source_created_at timestamptz, source_updated_at timestamptz,
    cp_detail_id bigint, legacy_operation_id text,
    effective_start_timestamp timestamptz, effective_end_timestamp timestamptz,
    active_flag boolean, updated_at timestamptz, row_version integer default 1);

create table raw_gmdf_core_deviation_qms.mdm_qms_organization (
    organization_id text, name text, created_date timestamptz, modified_date timestamptz,
    _is_current boolean default true, _source_deleted boolean default false);
create table raw_gmdf_core_deviation_qms.mdm_qms_deviation (
    level_2_organization_id text, level_3_organization_id text, source_system text,
    created_date timestamptz, last_modified_date timestamptz, date_closed timestamptz,
    _is_current boolean default true, _source_deleted boolean default false);
create table raw_gmdf_core_change_qms.mdm_qms_organization
    (like raw_gmdf_core_deviation_qms.mdm_qms_organization including defaults);
create table raw_gmdf_core_change_qms.mdm_qms_change_control
    (like raw_gmdf_core_deviation_qms.mdm_qms_deviation including defaults);
create table raw_gmdf_core_aud_insp_qms.mdm_qms_organization (
    organization_id text, created_date timestamptz, last_modified_date timestamptz,
    _is_current boolean default true, _source_deleted boolean default false);
create table raw_gmdf_core_aud_insp_qms.mdm_qms_audit (
    level_2_auditee_id text, auditable_unit_operations text, source_system text,
    actual_start_date timestamptz, actual_end_date timestamptz,
    created_date timestamptz, last_modified_date timestamptz,
    _is_current boolean default true, _source_deleted boolean default false);
create table raw_gmdf_core_complaint_qms.mdm_qms_organization
    (like raw_gmdf_core_deviation_qms.mdm_qms_organization including defaults);
create table raw_gmdf_core_complaint_qms.mdm_qms_complaint (
    responsible_organization_id text, source_system text,
    created_date timestamptz, modified_date timestamptz, closed_date timestamptz,
    _is_current boolean default true, _source_deleted boolean default false);

insert into core.cp_app_common_name
values (1, 'ORG', true, now() - interval '20 days');
insert into raw_gmdf_core_deviation_qms.mdm_qms_organization (
    organization_id, name, created_date, modified_date)
values ('ORG', 'Partner', now() - interval '20 days', now() - interval '10 days'),
       ('L3', 'Manufacturing', now() - interval '20 days', now() - interval '10 days');
insert into raw_gmdf_core_deviation_qms.mdm_qms_deviation (
    level_2_organization_id, level_3_organization_id, source_system,
    created_date, last_modified_date, date_closed)
values ('ORG', 'L3', 'QMS', now() - interval '10 days', now() - interval '9 days',
        now() - interval '8 days'),
       ('ORG', 'L3', 'QMS', now() - interval '7 days', now() - interval '6 days',
        now() - interval '5 days');

-- An upstream checkpoint must not suppress the first consumer load.
insert into ops.load_watermark values (
    1, 'raw_gmdf_core_deviation_qms.mdm_qms_deviation', now(), now());
\ir ../04_cp_app_operations.sql

do $$
begin
    if (select count(*) from core.cp_app_operations where active_flag) <> 1 then
        raise exception 'Initial load did not create exactly one current operation';
    end if;
end $$;

update core.cp_app_operations set cp_detail_id = 42, legacy_operation_id = 'retained';
update raw_gmdf_core_deviation_qms.mdm_qms_deviation
set date_closed = clock_timestamp() - interval '1 day',
    last_modified_date = clock_timestamp()
where created_date > now() - interval '8 days';
\ir ../04_cp_app_operations.sql

do $$
begin
    if (select count(*) from core.cp_app_operations) <> 2
       or (select count(*) from core.cp_app_operations where active_flag) <> 1 then
        raise exception 'Changed record was not closed and replaced exactly once';
    end if;
    if not exists (
        select 1 from core.cp_app_operations old
        join core.cp_app_operations new on old.cp_id = new.cp_id
        where not old.active_flag and new.active_flag
          and old.effective_end_timestamp = new.effective_start_timestamp
          and new.effective_from = cast(now() - interval '10 days' as date)
          and new.cp_detail_id = 42 and new.legacy_operation_id = 'retained'
    ) then
        raise exception 'History boundary, complete aggregation or carried fields are incorrect';
    end if;
end $$;

-- Correcting a business start date must close the same stable identity.
update raw_gmdf_core_deviation_qms.mdm_qms_deviation
set created_date = created_date - interval '2 days', last_modified_date = clock_timestamp()
where created_date < now() - interval '8 days';
\ir ../04_cp_app_operations.sql

do $$
begin
    if (select count(*) from core.cp_app_operations) <> 3
       or (select count(*) from core.cp_app_operations where active_flag) <> 1
       or (select effective_from from core.cp_app_operations where active_flag)
          <> cast(now() - interval '12 days' as date) then
        raise exception 'Start-date correction left the old version active';
    end if;
end $$;

-- A failed consumer batch must not advance the successful checkpoint.
insert into ops.load_batch (
    external_system_id, source_object, run_status_id, completed_at, watermark_to)
values (1, 'core.cp_app_operations', 3, now(), now() + interval '1 day');
\ir ../04_cp_app_operations.sql
do $$
begin
    if (select count(*) from core.cp_app_operations) <> 3 then
        raise exception 'Unchanged retry inserted another version';
    end if;
end $$;

update raw_gmdf_core_deviation_qms.mdm_qms_deviation
set date_closed = now() + interval '2 days', last_modified_date = now() + interval '1 day';
\ir ../04_cp_app_operations.sql
do $$
begin
    if (select count(*) from core.cp_app_operations) <> 3 then
        raise exception 'Future-dated source escaped the current-run cutoff';
    end if;
end $$;

-- Replay an older source value inside a deliberately reopened window.
update ops.load_batch set watermark_to = now() - interval '30 days'
where source_object = 'core.cp_app_operations' and run_status_id = 2;
update raw_gmdf_core_deviation_qms.mdm_qms_deviation
set date_closed = now() - interval '4 days', last_modified_date = now() - interval '3 days';
\ir ../04_cp_app_operations.sql
do $$
begin
    if (select count(*) from core.cp_app_operations) <> 3 then
        raise exception 'Stale source replaced a newer target version';
    end if;
    if not exists (
        select 1 from ops.load_watermark w join ops.load_batch b
          on b.external_system_id = w.external_system_id and b.source_object = w.source_object
         and b.watermark_to = w.watermark_value
        where w.source_object = 'core.cp_app_operations' and b.run_status_id = 2
    ) then
        raise exception 'Successful consumer progress was not persisted';
    end if;
end $$;

-- Exercise the remaining domains, including the complaint modified_date field
-- and the stable fallback when an audit has no business dates.
insert into core.cp_app_common_name values
    (2, 'CHANGE_ORG', true, now() - interval '20 days'),
    (3, 'AUDIT_ORG', true, now() - interval '20 days'),
    (4, 'COMPLAINT_ORG', true, now() - interval '20 days');
insert into raw_gmdf_core_change_qms.mdm_qms_organization (
    organization_id, name, created_date, modified_date)
values ('CHANGE_ORG', 'Partner', now() - interval '20 days', now() - interval '10 days'),
       ('CHANGE_L3', 'Manufacturing', now() - interval '20 days', now() - interval '10 days');
insert into raw_gmdf_core_change_qms.mdm_qms_change_control (
    level_2_organization_id, level_3_organization_id, source_system,
    created_date, last_modified_date)
values ('CHANGE_ORG', 'CHANGE_L3', 'QMS', now() - interval '8 days', now() - interval '7 days');
insert into raw_gmdf_core_aud_insp_qms.mdm_qms_organization (
    organization_id, created_date, last_modified_date)
values ('AUDIT_ORG', now() - interval '20 days', now() - interval '10 days');
insert into raw_gmdf_core_aud_insp_qms.mdm_qms_audit (
    level_2_auditee_id, auditable_unit_operations, source_system, last_modified_date)
values ('AUDIT_ORG', 'Manufacturing', 'QMS', now() - interval '7 days');
insert into raw_gmdf_core_complaint_qms.mdm_qms_organization (
    organization_id, name, created_date, modified_date)
values ('COMPLAINT_ORG', 'Partner', now() - interval '20 days', now() - interval '10 days');
insert into raw_gmdf_core_complaint_qms.mdm_qms_complaint (
    responsible_organization_id, source_system, created_date, modified_date)
values ('COMPLAINT_ORG', 'QMS', now() - interval '8 days', now() - interval '7 days');
\ir ../04_cp_app_operations.sql

do $$
begin
    if (select count(*) from core.cp_app_operations where active_flag) <> 4 then
        raise exception 'Change, audit or complaint branch failed to create its operation';
    end if;
end $$;
\ir ../04_cp_app_operations.sql
do $$
begin
    if (select count(*) from core.cp_app_operations where cp_id in (2, 3, 4)) <> 3 then
        raise exception 'Missing-date fallback or unchanged domain retry created duplicates';
    end if;
end $$;
