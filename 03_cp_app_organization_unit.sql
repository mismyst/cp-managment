-- Raw-to-core load query for core.cp_app_organization_unit (raw layer instead of GMDF, reference tables joined).
-- cp_id: core.cp_app_common_name.id where source_org_id = organization_id (the EDB column mapped for source_org_id); NULL when the unit is not a partner.
-- The source is reduced to one row per key first (MERGE fails when two source rows reach the same target row). PostgreSQL 15 or later.
-- Business key: (external_system_id, source_org_id). The same organisation sits in several domains: the latest source_last_modified wins.
--
-- ==================== SCD TYPE 2 VERSION ====================
-- core.cp_app_organization_unit keeps its FULL HISTORY with the columns effective_start_timestamp, effective_end_timestamp, active_flag.
--   * changed source row  -> the ACTIVE version is CLOSED (effective_end_timestamp = now(), active_flag = false) and a NEW version is INSERTED
--                            (effective_start_timestamp = now(), effective_end_timestamp = NULL, active_flag = true);
--   * new key             -> inserted as the first version;   unchanged row -> not touched.
-- now() is fixed for the whole transaction, so the end of the closed version equals the start of the new one (no gap, no overlap).
-- Steps (one transaction): 0 snapshot of the source in a temp table | 1 MERGE closes the changed active versions | 2 INSERT the new versions.
-- Columns kept from the previous version when a new version is written (set in the app / by the pipeline, not from the source):
--   load_batch_id, hierarchy_depth, parent_org_unit_id (refreshed by the second pass).
-- Joins to core tables read the ACTIVE version only (active_flag). Run 00_scd2_prerequisites.sql first (unique keys become partial: WHERE active_flag).
-- Active-version business key: (external_system_id, source_org_id).

begin;

-- Step 0: snapshot of the reduced source (one row per key), read once and used by steps 1 and 2.
create temp table tmp_src_cp_app_organization_unit on commit drop as
select z.*
    from (
        select base.*, row_number() over (partition by base.external_system_id, base.source_org_id order by base.source_last_modified desc nulls last, base.organization_name) as rn
        from (
            select  cn.id                                   as cp_id,                -- core.cp_app_common_name (only when the unit is a partner)
                    es.id                                   as external_system_id,   -- ref.external_system
                    s.source_org_id,
                    s.source_last_modified,
                    s.organization_name,
                    oc.id                                   as org_category_id,      -- ref.org_category
                    ctry.id                                 as country_id,           -- ref.country through ref.country_alias
                    s.sap_plant_code,
                    s.used_in,
                    coalesce(case lower(trim(s.status)) when 'active' then true when 'inactive' then false end, true) as is_active,
                    s.source_created_at,
                    s.source_updated_at
            from (
                  select  (select min(ev.source_system) from raw_gmdf_core_deviation_qms.mdm_qms_deviation ev
                           where ev.level_2_organization_id = o.organization_id and ev._is_current and not ev._source_deleted)   as source_system,
                          o.organization_id             as source_org_id,
                          o.modified_date                   as source_last_modified,
                          o.name                  as organization_name,
                          o.category                    as category,
                          o.parent_organization_id      as parent_source_id,
                          o.country_id                  as country_source,
                          o.sap_plant_code              as sap_plant_code,
                          o.used_in                     as used_in,
                          o.status                      as status,
                          o.created_date                as source_created_at,
                          o.modified_date                   as source_updated_at
                  from    raw_gmdf_core_deviation_qms.mdm_qms_organization o
                  where   o._is_current and not o._source_deleted
                  union all
                  select  (select min(ev.source_system) from raw_gmdf_core_aud_insp_qms.mdm_qms_audit ev
                           where ev.level_2_auditee_id = o.organization_id and ev._is_current and not ev._source_deleted)   as source_system,
                          o.organization_id             as source_org_id,
                          o.last_modified_date                   as source_last_modified,
                          o.organization_name                  as organization_name,
                          o.category                    as category,
                          o.parent_organization_id      as parent_source_id,
                          o.country_id                  as country_source,
                          o.sap_plant_code              as sap_plant_code,
                          o.used_in                     as used_in,
                          o.status                      as status,
                          o.created_date                as source_created_at,
                          o.last_modified_date                   as source_updated_at
                  from    raw_gmdf_core_aud_insp_qms.mdm_qms_organization o
                  where   o._is_current and not o._source_deleted
                  union all
                  select  (select min(ev.source_system) from raw_gmdf_core_change_qms.mdm_qms_change_control ev
                           where ev.level_2_organization_id = o.organization_id and ev._is_current and not ev._source_deleted)   as source_system,
                          o.organization_id             as source_org_id,
                          o.modified_date                   as source_last_modified,
                          o.name                  as organization_name,
                          o.category                    as category,
                          o.parent_organization_id      as parent_source_id,
                          o.country_id                  as country_source,
                          o.sap_plant_code              as sap_plant_code,
                          o.used_in                     as used_in,
                          o.status                      as status,
                          o.created_date                as source_created_at,
                          o.modified_date                   as source_updated_at
                  from    raw_gmdf_core_change_qms.mdm_qms_organization o
                  where   o._is_current and not o._source_deleted
                  union all
                  select  (select min(ev.source_system) from raw_gmdf_core_complaint_qms.mdm_qms_complaint ev
                           where ev.responsible_organization_id = o.organization_id and ev._is_current and not ev._source_deleted)   as source_system,
                          o.organization_id             as source_org_id,
                          o.modified_date                   as source_last_modified,
                          o.name                  as organization_name,
                          o.category                    as category,
                          o.parent_organization_id      as parent_source_id,
                          o.country_id                  as country_source,
                          o.sap_plant_code              as sap_plant_code,
                          o.used_in                     as used_in,
                          o.status                      as status,
                          o.created_date                as source_created_at,
                          o.modified_date                   as source_updated_at
                  from    raw_gmdf_core_complaint_qms.mdm_qms_organization o
                  where   o._is_current and not o._source_deleted
                 ) s
            join    ref.external_system es
                   on es.code = case upper(trim(coalesce(s.source_system, 'GMDF'))) when 'QMS' then 'QMS_VEEVA' else upper(trim(coalesce(s.source_system, 'GMDF'))) end           -- unit without events: GMDF
            left join (select * from core.cp_app_common_name where active_flag) cn on cast(cn.source_org_id as varchar(100)) = s.source_org_id
            left join ref.org_category oc
                   on lower(trim(oc.code)) = lower(trim(s.category)) or lower(trim(oc.name)) = lower(trim(s.category))
            left join ref.external_system gm on gm.code = 'GMDF'
            left join ref.country_alias ca
                   on ca.external_system_id = gm.id and lower(trim(ca.alias_value)) = lower(trim(s.country_source))
            left join ref.country ctry on ctry.id = ca.country_id
        ) as base (cp_id, external_system_id, source_org_id, source_last_modified, organization_name, org_category_id, country_id, sap_plant_code, used_in, is_active, source_created_at, source_updated_at)
    ) z
    where z.rn = 1;

-- Step 1: close the active version when a tracked column changed.
merge into core.cp_app_organization_unit as tgt
using tmp_src_cp_app_organization_unit as src
on (tgt.external_system_id = src.external_system_id
   and tgt.source_org_id = src.source_org_id
   and tgt.active_flag)
when matched and (
         tgt.cp_id is distinct from src.cp_id
      or tgt.source_last_modified is distinct from src.source_last_modified
      or tgt.organization_name is distinct from src.organization_name
      or tgt.org_category_id is distinct from src.org_category_id
      or tgt.country_id is distinct from src.country_id
      or tgt.sap_plant_code is distinct from src.sap_plant_code
      or tgt.used_in is distinct from src.used_in
      or tgt.is_active is distinct from src.is_active
      or tgt.source_created_at is distinct from src.source_created_at
      or tgt.source_updated_at is distinct from src.source_updated_at
     ) then
    update set effective_end_timestamp = now(),
               active_flag = false,
               updated_at = now(),
               row_version = tgt.row_version + 1;

-- Step 2: insert the new version for every key that has no active version (new keys and the keys closed in step 1).
insert into core.cp_app_organization_unit (
        cp_id,
        external_system_id,
        source_org_id,
        source_last_modified,
        organization_name,
        org_category_id,
        country_id,
        sap_plant_code,
        used_in,
        is_active,
        source_created_at,
        source_updated_at,
        load_batch_id,
        parent_org_unit_id,
        hierarchy_depth,
        effective_start_timestamp,
        effective_end_timestamp,
        active_flag)
select  src.cp_id,
        src.external_system_id,
        src.source_org_id,
        src.source_last_modified,
        src.organization_name,
        src.org_category_id,
        src.country_id,
        src.sap_plant_code,
        src.used_in,
        src.is_active,
        src.source_created_at,
        src.source_updated_at,
        prev.load_batch_id,
        prev.parent_org_unit_id,
        prev.hierarchy_depth,
        now(),
        cast(null as timestamptz),
        true
from    tmp_src_cp_app_organization_unit src
left join lateral (select p.* from core.cp_app_organization_unit p               -- latest previous version of the key (if any)
                   where p.external_system_id = src.external_system_id
                     and p.source_org_id = src.source_org_id
                   order by p.effective_start_timestamp desc, p.id desc
                   limit 1) prev on true
where   not exists (select 1 from core.cp_app_organization_unit a
                    where a.external_system_id = src.external_system_id
                      and a.source_org_id = src.source_org_id
                      and a.active_flag);

-- Second pass (units must exist first): parent_org_unit_id, SCD Type 2.
-- A change of parent closes the unit's active version and inserts a new version with the new parent. When a PARENT gets a new version, its children
-- point to the closed id and are versioned in the next iteration; the loop repeats until nothing changes (at most 20 levels).
do $$
declare
    v_rows integer;
    v_iter integer := 0;
begin
    loop
        v_iter := v_iter + 1;
        create temp table tmp_org_parent_chg on commit drop as
        select u.id as old_id, u.cp_id, u.external_system_id, u.source_org_id, u.source_last_modified, u.load_batch_id, u.organization_name, u.org_category_id, u.country_id, u.sap_plant_code, u.used_in, u.hierarchy_depth, u.is_active, u.source_created_at, u.source_updated_at, p.new_parent_id
        from   core.cp_app_organization_unit u
        join  (select g.source_org_id,
                      (select min(pu.id) from core.cp_app_organization_unit pu
                       where  pu.active_flag and pu.source_org_id = g.parent_source_id) as new_parent_id
               from  (select s.source_org_id, min(s.parent_source_id) as parent_source_id
                      from  (
                             select o.organization_id as source_org_id, o.parent_organization_id as parent_source_id from raw_gmdf_core_deviation_qms.mdm_qms_organization o where o._is_current and not o._source_deleted and o.parent_organization_id is not null
                             union
                             select o.organization_id, o.parent_organization_id from raw_gmdf_core_aud_insp_qms.mdm_qms_organization o where o._is_current and not o._source_deleted and o.parent_organization_id is not null
                             union
                             select o.organization_id, o.parent_organization_id from raw_gmdf_core_change_qms.mdm_qms_organization o where o._is_current and not o._source_deleted and o.parent_organization_id is not null
                             union
                             select o.organization_id, o.parent_organization_id from raw_gmdf_core_complaint_qms.mdm_qms_organization o where o._is_current and not o._source_deleted and o.parent_organization_id is not null
                            ) s
                      group by s.source_org_id) g) p on p.source_org_id = u.source_org_id
        where  u.active_flag
          and  p.new_parent_id is not null
          and  u.parent_org_unit_id is distinct from p.new_parent_id;

        -- close the old versions
        update core.cp_app_organization_unit u
        set    effective_end_timestamp = now(), active_flag = false, updated_at = now(), row_version = u.row_version + 1
        from   tmp_org_parent_chg c
        where  u.id = c.old_id;

        -- insert the new versions with the new parent
        insert into core.cp_app_organization_unit (
                cp_id,
        external_system_id,
        source_org_id,
        source_last_modified,
        load_batch_id,
        organization_name,
        org_category_id,
        country_id,
        sap_plant_code,
        used_in,
        hierarchy_depth,
        is_active,
        source_created_at,
        source_updated_at,
        parent_org_unit_id,
        effective_start_timestamp,
        effective_end_timestamp,
        active_flag)
        select  c.cp_id,
        c.external_system_id,
        c.source_org_id,
        c.source_last_modified,
        c.load_batch_id,
        c.organization_name,
        c.org_category_id,
        c.country_id,
        c.sap_plant_code,
        c.used_in,
        c.hierarchy_depth,
        c.is_active,
        c.source_created_at,
        c.source_updated_at,
                c.new_parent_id, now(), cast(null as timestamptz), true
        from    tmp_org_parent_chg c;

        get diagnostics v_rows = row_count;
        drop table tmp_org_parent_chg;
        exit when v_rows = 0 or v_iter >= 20;
    end loop;
end $$;

commit;
