-- Raw-to-core load query for core.cp_app_quality_events (raw layer instead of GMDF, reference tables joined).
-- cp_id: core.cp_app_common_name.id where source_org_id = level_2_organization_id (the EDB column mapped for source_org_id); NULL when the plant is not a partner.
-- The source is reduced to one row per key first (MERGE fails when two source rows reach the same target row). PostgreSQL 15 or later.
-- Business key: (external_system_id, source_record_id). Columns set in the app (is_manual, applicable_tr, issue category, entered by) are not touched.
--
-- ==================== SCD TYPE 2 VERSION ====================
-- core.cp_app_quality_events keeps its FULL HISTORY with the columns effective_start_timestamp, effective_end_timestamp, active_flag.
--   * changed source row  -> the ACTIVE version is CLOSED (effective_end_timestamp = now(), active_flag = false) and a NEW version is INSERTED
--                            (effective_start_timestamp = now(), effective_end_timestamp = NULL, active_flag = true);
--   * new key             -> inserted as the first version;   unchanged row -> not touched.
-- now() is fixed for the whole transaction, so the end of the closed version equals the start of the new one (no gap, no overlap).
-- Steps (one transaction): 0 snapshot of the source in a temp table | 1 MERGE closes the changed active versions | 2 INSERT the new versions.
-- Columns kept from the previous version when a new version is written (set in the app / by the pipeline, not from the source):
--   load_batch_id, issue_category_id, originating_org_unit_id, applicable_tr, is_manual, entered_by_user_id.
-- Joins to core tables read the ACTIVE version only (active_flag). Run 00_scd2_prerequisites.sql first (unique keys become partial: WHERE active_flag).
-- Active-version business key: (external_system_id, source_record_id).

begin;

-- Step 0: snapshot of the reduced source (one row per key), read once and used by steps 1 and 2.
create temp table tmp_src_cp_app_quality_events on commit drop as
select z.*
    from (
        select base.*, row_number() over (partition by base.external_system_id, base.source_record_id order by base.source_updated_at desc nulls last) as rn
        from (
            select  cn.id                                   as cp_id,                -- core.cp_app_common_name (NULL when the plant is not a partner)
                    qt.id                                   as event_type_id,        -- ref.quality_event_type
                    es.id                                   as external_system_id,   -- ref.external_system
                    s.record_number                         as source_record_id,     -- assumed: the record number (keeps the unique source index effective)
                    s.level_2_org                           as source_org_id,
                    s.record_number,
                    s.title,
                    s.description,
                    cla.event_classification_id             as classification_id,    -- ref.event_classification_alias → ref.event_classification
                    icla.event_classification_id            as initial_classification_id,
                    sta.event_status_id                     as event_status_id,      -- ref.event_status_alias → ref.event_status
                    s.source_status_text,
                    cast(s.created_date as date)            as date_created,
                    cast(s.date_discovered as date)         as date_discovered,
                    cast(s.date_occurred as date)           as date_occurred,
                    cast(s.date_closed as date)             as date_closed,
                    cq.id                                   as created_quarter_id,   -- ref.cp_app_qtr_table
                    xq.id                                   as closed_quarter_id,
                    (select min(ou.id) from (select * from core.cp_app_organization_unit where active_flag) ou where ou.source_org_id = s.level_2_org)                   as plant_org_unit_id,         -- core.cp_app_organization_unit
                    (select min(ou.id) from (select * from core.cp_app_organization_unit where active_flag) ou where ou.source_org_id = s.level_4_org)                   as process_team_org_unit_id,
                    (select min(ou.id) from (select * from core.cp_app_organization_unit where active_flag) ou where ou.source_org_id = s.level_3_org)                   as flow_team_org_unit_id,
                    s.site_name, s.plant_name, s.process_team_name, s.flow_team_name,
                    (upper(trim(s.source_system)) = 'TW1000CD') as is_early_phase,
                    s.created_date                          as source_created_at,
                    s.last_modified_date                    as source_updated_at
            from (
                  select  'DEVIATION' as event_type_code, d.source_system,
                          d.level_2_organization_id as level_2_org, d.level_3_organization_id as level_3_org, d.level_4_organization_id as level_4_org,
                          d.deviation_number as record_number, d.deviation_title as title, d.description as description,
                          d.final_classification as classification_text, cast(null as varchar(255)) as initial_classification_text,
                          coalesce(d.trw_lifecycle_state, d.lifecycle_state) as status_text, cast(null as varchar(60)) as source_status_text,
                          d.created_date, d.date_discovered, d.date_occurred, d.date_closed,
                          d.trw_site_name as site_name, d.trw_plant_name as plant_name, d.trw_process_team_name as process_team_name, d.trw_flow_team_name as flow_team_name,
                          d.last_modified_date
                  from    raw_gmdf_core_deviation_qms.mdm_qms_deviation d
                  where   d._is_current and not d._source_deleted
                  union all
                  select  'CHANGE', c.source_system,
                          c.level_2_organization_id, c.level_3_organization_id, c.level_4_organization_id,
                          c.change_number, c.change_title, c.change_description,
                          c.highest_change_classification, c.change_classification,
                          coalesce(c.trw_lifecycle_state, c.lifecycle_state), c.status,
                          c.created_date, cast(null as timestamp), cast(null as date), c.date_closed,
                          c.trw_level_1_org_name, c.trw_level_2_org_name, c.trw_level_3_org_name, c.trw_level_4_org_name,
                          c.last_modified_date
                  from    raw_gmdf_core_change_qms.mdm_qms_change_control c
                  where   c._is_current and not c._source_deleted
                  union all
                  select  'ICI', qi.source_system,
                          qi.level_2_organization_id, cast(null as varchar(100)), cast(null as varchar(100)),
                          qi.quality_incident_number, cast(null as varchar(255)), cast(null as text),
                          cast(null as varchar(255)), cast(null as varchar(255)),
                          cast(null as varchar(255)), qi.status,
                          qi.created_date, cast(null as timestamp), cast(null as date), cast(null as timestamp),
                          cast(null as varchar(120)), cast(null as varchar(120)), cast(null as varchar(120)), cast(null as varchar(120)),
                          qi.last_modified_date
                  from    raw_gmdf_core_deviation_qms.mdm_qms_quality_incident qi
                  where   qi._is_current and not qi._source_deleted
                 ) s
            join    ref.external_system es on es.code = case upper(trim(s.source_system)) when 'QMS' then 'QMS_VEEVA' else upper(trim(s.source_system)) end
            join    ref.quality_event_type qt on qt.code = s.event_type_code
            left join (select * from core.cp_app_common_name where active_flag) cn on cast(cn.source_org_id as varchar(100)) = s.level_2_org
            left join ref.event_classification_alias cla
                   on cla.external_system_id = es.id and lower(trim(cla.alias_value)) = lower(trim(s.classification_text))
            left join ref.event_classification_alias icla
                   on icla.external_system_id = es.id and lower(trim(icla.alias_value)) = lower(trim(s.initial_classification_text))
            left join ref.event_status_alias sta
                   on sta.external_system_id = es.id and lower(trim(sta.alias_value)) = lower(trim(s.status_text))
            left join ref.cp_app_qtr_table cq on cast(s.created_date as date) between cq.start_date and cq.end_date
            left join ref.cp_app_qtr_table xq on cast(s.date_closed as date) between xq.start_date and xq.end_date
            where   s.record_number is not null and s.created_date is not null
        ) as base (cp_id, event_type_id, external_system_id, source_record_id, source_org_id, record_number, title, description, classification_id, initial_classification_id, event_status_id, source_status_text, date_created, date_discovered, date_occurred, date_closed, created_quarter_id, closed_quarter_id, plant_org_unit_id, process_team_org_unit_id, flow_team_org_unit_id, source_site_name, source_plant_name, source_process_team_name, source_flow_team_name, is_early_phase, source_created_at, source_updated_at)
    ) z
    where z.rn = 1;

-- Step 1: close the active version when a tracked column changed.
merge into core.cp_app_quality_events as tgt
using tmp_src_cp_app_quality_events as src
on (tgt.external_system_id = src.external_system_id
   and tgt.source_record_id = src.source_record_id
   and tgt.active_flag)
when matched and (
         tgt.cp_id is distinct from src.cp_id
      or tgt.event_type_id is distinct from src.event_type_id
      or tgt.source_org_id is distinct from src.source_org_id
      or tgt.record_number is distinct from src.record_number
      or tgt.title is distinct from src.title
      or tgt.description is distinct from src.description
      or tgt.classification_id is distinct from src.classification_id
      or tgt.initial_classification_id is distinct from src.initial_classification_id
      or tgt.event_status_id is distinct from src.event_status_id
      or tgt.source_status_text is distinct from src.source_status_text
      or tgt.date_created is distinct from src.date_created
      or tgt.date_discovered is distinct from src.date_discovered
      or tgt.date_occurred is distinct from src.date_occurred
      or tgt.date_closed is distinct from src.date_closed
      or tgt.created_quarter_id is distinct from src.created_quarter_id
      or tgt.closed_quarter_id is distinct from src.closed_quarter_id
      or tgt.plant_org_unit_id is distinct from src.plant_org_unit_id
      or tgt.process_team_org_unit_id is distinct from src.process_team_org_unit_id
      or tgt.flow_team_org_unit_id is distinct from src.flow_team_org_unit_id
      or tgt.source_site_name is distinct from src.source_site_name
      or tgt.source_plant_name is distinct from src.source_plant_name
      or tgt.source_process_team_name is distinct from src.source_process_team_name
      or tgt.source_flow_team_name is distinct from src.source_flow_team_name
      or tgt.is_early_phase is distinct from src.is_early_phase
      or tgt.source_created_at is distinct from src.source_created_at
      or tgt.source_updated_at is distinct from src.source_updated_at
     ) then
    update set effective_end_timestamp = now(),
               active_flag = false,
               updated_at = now(),
               row_version = tgt.row_version + 1;

-- Step 2: insert the new version for every key that has no active version (new keys and the keys closed in step 1).
insert into core.cp_app_quality_events (
        cp_id,
        event_type_id,
        external_system_id,
        source_record_id,
        source_org_id,
        record_number,
        title,
        description,
        classification_id,
        initial_classification_id,
        event_status_id,
        source_status_text,
        date_created,
        date_discovered,
        date_occurred,
        date_closed,
        created_quarter_id,
        closed_quarter_id,
        plant_org_unit_id,
        process_team_org_unit_id,
        flow_team_org_unit_id,
        source_site_name,
        source_plant_name,
        source_process_team_name,
        source_flow_team_name,
        is_early_phase,
        source_created_at,
        source_updated_at,
        load_batch_id,
        issue_category_id,
        originating_org_unit_id,
        applicable_tr,
        is_manual,
        entered_by_user_id,
        effective_start_timestamp,
        effective_end_timestamp,
        active_flag)
select  src.cp_id,
        src.event_type_id,
        src.external_system_id,
        src.source_record_id,
        src.source_org_id,
        src.record_number,
        src.title,
        src.description,
        src.classification_id,
        src.initial_classification_id,
        src.event_status_id,
        src.source_status_text,
        src.date_created,
        src.date_discovered,
        src.date_occurred,
        src.date_closed,
        src.created_quarter_id,
        src.closed_quarter_id,
        src.plant_org_unit_id,
        src.process_team_org_unit_id,
        src.flow_team_org_unit_id,
        src.source_site_name,
        src.source_plant_name,
        src.source_process_team_name,
        src.source_flow_team_name,
        src.is_early_phase,
        src.source_created_at,
        src.source_updated_at,
        prev.load_batch_id,
        prev.issue_category_id,
        prev.originating_org_unit_id,
        prev.applicable_tr,
        coalesce(prev.is_manual, false),
        prev.entered_by_user_id,
        now(),
        cast(null as timestamptz),
        true
from    tmp_src_cp_app_quality_events src
left join lateral (select p.* from core.cp_app_quality_events p               -- latest previous version of the key (if any)
                   where p.external_system_id = src.external_system_id
                     and p.source_record_id = src.source_record_id
                   order by p.effective_start_timestamp desc, p.id desc
                   limit 1) prev on true
where   not exists (select 1 from core.cp_app_quality_events a
                    where a.external_system_id = src.external_system_id
                      and a.source_record_id = src.source_record_id
                      and a.active_flag);

commit;
