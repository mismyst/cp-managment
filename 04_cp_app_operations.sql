-- PostgreSQL 15+. SCD2 business key: (cp_id, operation_group_id).
-- effective_from is tracked data, not identity: correcting it closes and replaces the same operation.
-- The GMDF/core.cp_app_operations checkpoint belongs to this consumer, not to the raw ingestion jobs.
-- Process changes in [last successful watermark_to, run cutoff], with an inclusive retry boundary.
-- Raw timestamps must represent committed changes visible to this load; backdated arrivals need replay.
-- Full current source groups are aggregated before applying the incremental filter.
-- Deletions and operation-group/partner identity changes require separate reconciliation.
-- Prerequisites: ops.load_batch, ops.load_watermark, ref.external_system (GMDF),
-- ref.run_status (RUNNING, SUCCEEDED), and SCD2 target columns.
-- Enforce one active row per (cp_id, operation_group_id) with a partial unique index.

begin;

-- Serialize this target's writers before capturing the run boundary.
lock table core.cp_app_operations in share row exclusive mode;

create temp table tmp_operations_run (
    external_system_id integer not null,
    running_status_id integer not null,
    succeeded_status_id integer not null,
    watermark_from timestamptz not null,
    watermark_to timestamptz not null,
    rows_updated integer not null default 0,
    rows_inserted integer not null default 0
) on commit drop;

insert into tmp_operations_run (
    external_system_id, running_status_id, succeeded_status_id, watermark_from, watermark_to)
select (select id from ref.external_system where code = 'GMDF'),
       (select id from ref.run_status where code = 'RUNNING'),
       (select id from ref.run_status where code = 'SUCCEEDED'),
       coalesce((
           select max(b.watermark_to)
           from ops.load_batch b
           join ref.external_system es on es.id = b.external_system_id and es.code = 'GMDF'
           join ref.run_status rs on rs.id = b.run_status_id and rs.code = 'SUCCEEDED'
           where b.source_object = 'core.cp_app_operations'
             and b.completed_at is not null
       ), timestamptz '1900-01-01 00:00:00+00'),
       clock_timestamp();

do $$
begin
    if exists (select 1 from tmp_operations_run where watermark_from > watermark_to) then
        raise exception 'Operations checkpoint is later than the current run cutoff';
    end if;
    if exists (
        select 1 from core.cp_app_operations
        where active_flag
        group by cp_id, operation_group_id having count(*) > 1
    ) then
        raise exception 'Reconcile duplicate active partner/operation groups before running this load';
    end if;
end $$;

create unique index if not exists cp_app_operations_active_partner_group_uk
    on core.cp_app_operations (cp_id, operation_group_id) where active_flag;

create temp table tmp_operations_batch on commit drop as
with started as (
    insert into ops.load_batch (
        external_system_id, source_object, run_status_id, started_at, watermark_from)
    select external_system_id, 'core.cp_app_operations', running_status_id,
           watermark_to, watermark_from
    from tmp_operations_run
    returning id
)
select id from started;

create temp table tmp_src_cp_app_operations on commit drop as
with source_groups as (
    select o.organization_id as source_org_id, l3.name as operation_text, ev.source_system,
           min(ev.created_date) as effective_from, max(ev.date_closed) as effective_to,
           min(ev.created_date) as source_created_at,
           greatest(max(ev.last_modified_date), max(ev.created_date),
                    max(o.modified_date), max(o.created_date),
                    max(l3.modified_date), max(l3.created_date)) as source_updated_at
    from raw_gmdf_core_deviation_qms.mdm_qms_organization o
    join raw_gmdf_core_deviation_qms.mdm_qms_deviation ev
      on ev.level_2_organization_id = o.organization_id and ev._is_current and not ev._source_deleted
    join raw_gmdf_core_deviation_qms.mdm_qms_organization l3
      on l3.organization_id = ev.level_3_organization_id and l3._is_current and not l3._source_deleted
    where o._is_current and not o._source_deleted
    group by o.organization_id, l3.name, ev.source_system
    union all
    select o.organization_id, l3.name, ev.source_system,
           min(ev.created_date), max(ev.date_closed), min(ev.created_date),
           greatest(max(ev.last_modified_date), max(ev.created_date),
                    max(o.modified_date), max(o.created_date),
                    max(l3.modified_date), max(l3.created_date))
    from raw_gmdf_core_change_qms.mdm_qms_organization o
    join raw_gmdf_core_change_qms.mdm_qms_change_control ev
      on ev.level_2_organization_id = o.organization_id and ev._is_current and not ev._source_deleted
    join raw_gmdf_core_change_qms.mdm_qms_organization l3
      on l3.organization_id = ev.level_3_organization_id and l3._is_current and not l3._source_deleted
    where o._is_current and not o._source_deleted
    group by o.organization_id, l3.name, ev.source_system
    union all
    select o.organization_id, ev.auditable_unit_operations, ev.source_system,
           min(ev.actual_start_date), max(ev.actual_end_date), min(ev.created_date),
           greatest(max(ev.last_modified_date), max(ev.created_date),
                    max(o.last_modified_date), max(o.created_date))
    from raw_gmdf_core_aud_insp_qms.mdm_qms_organization o
    join raw_gmdf_core_aud_insp_qms.mdm_qms_audit ev
      on ev.level_2_auditee_id = o.organization_id and ev._is_current and not ev._source_deleted
    where o._is_current and not o._source_deleted
      and ev.auditable_unit_operations is not null
    group by o.organization_id, ev.auditable_unit_operations, ev.source_system
    union all
    select o.organization_id, 'TBD', ev.source_system,
           min(ev.created_date), max(ev.closed_date), min(ev.created_date),
           greatest(max(ev.modified_date), max(ev.created_date),
                    max(o.modified_date), max(o.created_date))
    from raw_gmdf_core_complaint_qms.mdm_qms_organization o
    join raw_gmdf_core_complaint_qms.mdm_qms_complaint ev
      on ev.responsible_organization_id = o.organization_id and ev._is_current and not ev._source_deleted
    where o._is_current and not o._source_deleted
    group by o.organization_id, ev.source_system
), mapped as (
    select cn.id as cp_id,
           coalesce(oga.operation_group_id,
                    1 + (hashtext(cast(cn.id as text)) & 2147483647) % 3) as operation_group_id,
           s.source_org_id, s.effective_from, s.effective_to, s.source_created_at,
           greatest(s.source_updated_at, cn.effective_start_timestamp) as source_updated_at
    from source_groups s
    join ref.external_system es
      on es.code = case upper(trim(s.source_system))
                       when 'QMS' then 'QMS_VEEVA' else upper(trim(s.source_system)) end
    left join ref.operation_group_alias oga
      on oga.external_system_id = es.id
     and lower(trim(oga.alias_value)) = lower(trim(s.operation_text))
    join core.cp_app_common_name cn
      on cast(cn.source_org_id as varchar(100)) = s.source_org_id and cn.active_flag
), grouped as (
    select cp_id, operation_group_id, source_org_id,
           cast(min(effective_from) as date) as effective_from,
           cast(max(effective_to) as date) as effective_to,
           min(source_created_at) as source_created_at,
           max(source_updated_at) as source_updated_at
    from mapped
    group by cp_id, operation_group_id, source_org_id
)
select g.cp_id, g.operation_group_id,
       coalesce(g.effective_from, cast(g.source_created_at as date),
                prev.effective_from, cast(r.watermark_to as date)) as effective_from,
       g.effective_to, g.source_org_id, g.source_created_at, g.source_updated_at,
       prev.cp_detail_id, prev.legacy_operation_id
from grouped g
cross join tmp_operations_run r
left join lateral (
    select p.effective_from, p.cp_detail_id, p.legacy_operation_id
    from core.cp_app_operations p
    where p.cp_id = g.cp_id and p.operation_group_id = g.operation_group_id
    order by p.effective_start_timestamp desc, p.id desc
    limit 1
) prev on true
where coalesce(g.source_updated_at, r.watermark_from) <= r.watermark_to
  and (
      coalesce(g.source_updated_at, r.watermark_from) >= r.watermark_from
      or not exists (
          select 1 from core.cp_app_operations a
          where a.cp_id = g.cp_id and a.operation_group_id = g.operation_group_id
            and a.active_flag
      )
  );

-- Fail rather than let multiple source rows close or replace the same active version.
create unique index on tmp_src_cp_app_operations (cp_id, operation_group_id);

do $$
declare
    v_closed integer;
    v_inserted integer;
begin
    merge into core.cp_app_operations as tgt
    using tmp_src_cp_app_operations as src
    on (tgt.cp_id = src.cp_id
        and tgt.operation_group_id = src.operation_group_id
        and tgt.active_flag)
    when matched
         and (tgt.source_updated_at is null or src.source_updated_at >= tgt.source_updated_at)
         and (
             tgt.effective_from is distinct from src.effective_from
             or tgt.effective_to is distinct from src.effective_to
             or tgt.source_org_id is distinct from src.source_org_id
             or tgt.source_created_at is distinct from src.source_created_at
             or tgt.source_updated_at is distinct from src.source_updated_at
         ) then
        update set effective_end_timestamp = (select watermark_to from tmp_operations_run),
                   active_flag = false,
                   updated_at = (select watermark_to from tmp_operations_run),
                   row_version = tgt.row_version + 1;
    get diagnostics v_closed = row_count;

    insert into core.cp_app_operations (
        cp_id, operation_group_id, effective_from, effective_to,
        source_org_id, source_created_at, source_updated_at,
        cp_detail_id, legacy_operation_id,
        effective_start_timestamp, effective_end_timestamp, active_flag)
    select src.cp_id, src.operation_group_id, src.effective_from, src.effective_to,
           src.source_org_id, src.source_created_at, src.source_updated_at,
           src.cp_detail_id, src.legacy_operation_id, r.watermark_to, null, true
    from tmp_src_cp_app_operations src
    cross join tmp_operations_run r
    where not exists (
        select 1 from core.cp_app_operations a
        where a.cp_id = src.cp_id and a.operation_group_id = src.operation_group_id
          and a.active_flag
    );
    get diagnostics v_inserted = row_count;

    update tmp_operations_run set rows_updated = v_closed, rows_inserted = v_inserted;
end $$;

-- Target changes and successful consumer progress commit together; an error rolls both back.
update ops.load_batch b
set run_status_id = r.succeeded_status_id,
    completed_at = clock_timestamp(),
    watermark_to = r.watermark_to,
    rows_read = (select count(*) from tmp_src_cp_app_operations),
    rows_inserted = r.rows_inserted,
    rows_updated = r.rows_updated,
    rows_rejected = 0
from tmp_operations_run r, tmp_operations_batch started
where b.id = started.id;

insert into ops.load_watermark (external_system_id, source_object, watermark_value, updated_at)
select external_system_id, 'core.cp_app_operations', watermark_to, clock_timestamp()
from tmp_operations_run
on conflict (external_system_id, source_object)
do update set watermark_value = excluded.watermark_value, updated_at = excluded.updated_at;

commit;
