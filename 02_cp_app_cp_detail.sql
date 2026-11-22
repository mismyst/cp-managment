-- Raw-to-core load query for core.cp_app_cp_detail (raw layer instead of GMDF, reference tables joined).
-- cp_id: core.cp_app_common_name.id where source_org_id = organization_id (the EDB column mapped for source_org_id).
-- The source is reduced to one row per key first (MERGE fails when two source rows reach the same target row). PostgreSQL 15 or later.
-- Business key: (cp_id, site_name), the unique key of the table. is_primary is not touched (set in the app).
--
-- ==================== SCD TYPE 2 VERSION ====================
-- core.cp_app_cp_detail keeps its FULL HISTORY with the columns effective_start_timestamp, effective_end_timestamp, active_flag.
--   * changed source row  -> the ACTIVE version is CLOSED (effective_end_timestamp = now(), active_flag = false) and a NEW version is INSERTED
--                            (effective_start_timestamp = now(), effective_end_timestamp = NULL, active_flag = true);
--   * new key             -> inserted as the first version;   unchanged row -> not touched.
-- now() is fixed for the whole transaction, so the end of the closed version equals the start of the new one (no gap, no overlap).
-- Steps (one transaction): 0 snapshot of the source in a temp table | 1 MERGE closes the changed active versions | 2 INSERT the new versions.
-- Columns kept from the previous version when a new version is written (set in the app / by the pipeline, not from the source):
--   new_street_address, new_street_2, new_city, new_region, new_postal_code, new_country_id, is_primary, site_comments, legacy_cpdetail_id, is_manual.
-- Joins to core tables read the ACTIVE version only (active_flag). Run 00_scd2_prerequisites.sql first (unique keys become partial: WHERE active_flag).
-- Active-version business key: (cp_id, site_name).

begin;

-- Step 0: snapshot of the reduced source (one row per key), read once and used by steps 1 and 2.
create temp table tmp_src_cp_app_cp_detail on commit drop as
select z.*
    from (
        select base.*, row_number() over (partition by base.cp_id, base.site_name order by base.source_updated_at desc nulls last) as rn
        from (
            select  d.cp_id, d.site_name, d.street_address, d.street_2, d.city, d.region, d.postal_code, d.country_id, d.is_active,
                    d.source_org_id, d.source_created_at, d.source_updated_at
            from (
                  select  cn.id                                 as cp_id,                -- core.cp_app_common_name
                          s.site_name, s.street_address, s.street_2, s.city, s.region, s.postal_code,
                          (select min(ca.country_id)                                      -- ref.country through ref.country_alias
                           from   ref.country_alias ca
                           join   ref.external_system e on e.id = ca.external_system_id
                           where  e.code in ('SAP', 'GMDF') and lower(trim(ca.alias_value)) = lower(trim(s.country_source))) as country_id,
                          coalesce(case lower(trim(s.status)) when 'active' then true when 'inactive' then false end, true) as is_active,
                          s.source_org_id, s.source_created_at, s.source_updated_at,
                          row_number() over (partition by cn.id, s.site_name order by s.priority) as rn      -- one site per partner and name: the same organisation sits in several domains
                  from (
                        select  1 as priority, mqo.organization_id as source_org_id, mqo.name as site_name,
                                ms.address_line_desc_1 as street_address, ms.address_line_desc_2 as street_2, ms.city_desc as city,
                                ms.state_province_cd as region, ms.postal_area_cd as postal_code, ms.country_desc as country_source,
                                tpqm.status as status, tpqm.created_date as source_created_at, tpqm.last_modified_date as source_updated_at
                        from    raw_gmdf_core.mdm_supplier ms
                        join    raw_gmdf_core_tpqm_qms.mdm_qms_external_party tpqm
                               on ms.sap_id = tpqm.sap_mp_number and tpqm._is_current and not tpqm._source_deleted
                        join    raw_gmdf_core_deviation_qms.mdm_qms_organization mqo
                               on mqo.organization_id = tpqm.external_party_id and mqo._is_current and not mqo._source_deleted
                        where   ms._is_current and not ms._source_deleted
                        union all
                        select  2 as priority, mqo.organization_id as source_org_id, mqo.name as site_name,
                                ms.address_line_desc_1 as street_address, ms.address_line_desc_2 as street_2, ms.city_desc as city,
                                ms.state_province_cd as region, ms.postal_area_cd as postal_code, ms.country_desc as country_source,
                                tpqm.status as status, tpqm.created_date as source_created_at, tpqm.last_modified_date as source_updated_at
                        from    raw_gmdf_core.mdm_supplier ms
                        join    raw_gmdf_core_tpqm_qms.mdm_qms_external_party tpqm
                               on ms.sap_id = tpqm.sap_mp_number and tpqm._is_current and not tpqm._source_deleted
                        join    raw_gmdf_core_change_qms.mdm_qms_organization mqo
                               on mqo.organization_id = tpqm.external_party_id and mqo._is_current and not mqo._source_deleted
                        where   ms._is_current and not ms._source_deleted
                        union all
                        select  3 as priority, mqo.organization_id as source_org_id, mqo.organization_name as site_name,
                                ms.address_line_desc_1 as street_address, ms.address_line_desc_2 as street_2, ms.city_desc as city,
                                ms.state_province_cd as region, ms.postal_area_cd as postal_code, ms.country_desc as country_source,
                                tpqm.status as status, tpqm.created_date as source_created_at, tpqm.last_modified_date as source_updated_at
                        from    raw_gmdf_core.mdm_supplier ms
                        join    raw_gmdf_core_tpqm_qms.mdm_qms_external_party tpqm
                               on ms.sap_id = tpqm.sap_mp_number and tpqm._is_current and not tpqm._source_deleted
                        join    raw_gmdf_core_aud_insp_qms.mdm_qms_organization mqo
                               on mqo.organization_id = tpqm.external_party_id and mqo._is_current and not mqo._source_deleted
                        where   ms._is_current and not ms._source_deleted
                        union all
                        select  4 as priority, mqo.organization_id as source_org_id, mqo.name as site_name,
                                ms.address_line_desc_1 as street_address, ms.address_line_desc_2 as street_2, ms.city_desc as city,
                                ms.state_province_cd as region, ms.postal_area_cd as postal_code, ms.country_desc as country_source,
                                tpqm.status as status, tpqm.created_date as source_created_at, tpqm.last_modified_date as source_updated_at
                        from    raw_gmdf_core.mdm_supplier ms
                        join    raw_gmdf_core_tpqm_qms.mdm_qms_external_party tpqm
                               on ms.sap_id = tpqm.sap_mp_number and tpqm._is_current and not tpqm._source_deleted
                        join    raw_gmdf_core_complaint_qms.mdm_qms_organization mqo
                               on mqo.organization_id = tpqm.external_party_id and mqo._is_current and not mqo._source_deleted
                        where   ms._is_current and not ms._source_deleted
                       ) s
                  join    (select * from core.cp_app_common_name where active_flag) cn on cast(cn.source_org_id as varchar(100)) = s.source_org_id
                  where   s.site_name is not null
                 ) d
            where   d.rn = 1
        ) as base (cp_id, site_name, street_address, street_2, city, region, postal_code, country_id, is_active, source_org_id, source_created_at, source_updated_at)
    ) z
    where z.rn = 1;

-- Step 1: close the active version when a tracked column changed.
merge into core.cp_app_cp_detail as tgt
using tmp_src_cp_app_cp_detail as src
on (tgt.cp_id = src.cp_id
   and tgt.site_name = src.site_name
   and tgt.active_flag)
when matched and (
         tgt.street_address is distinct from src.street_address
      or tgt.street_2 is distinct from src.street_2
      or tgt.city is distinct from src.city
      or tgt.region is distinct from src.region
      or tgt.postal_code is distinct from src.postal_code
      or tgt.country_id is distinct from src.country_id
      or tgt.is_active is distinct from src.is_active
      or tgt.source_org_id is distinct from src.source_org_id
      or tgt.source_created_at is distinct from src.source_created_at
      or tgt.source_updated_at is distinct from src.source_updated_at
     ) then
    update set effective_end_timestamp = now(),
               active_flag = false,
               updated_at = now(),
               row_version = tgt.row_version + 1;

-- Step 2: insert the new version for every key that has no active version (new keys and the keys closed in step 1).
insert into core.cp_app_cp_detail (
        cp_id,
        site_name,
        street_address,
        street_2,
        city,
        region,
        postal_code,
        country_id,
        is_active,
        source_org_id,
        source_created_at,
        source_updated_at,
        new_street_address,
        new_street_2,
        new_city,
        new_region,
        new_postal_code,
        new_country_id,
        is_primary,
        site_comments,
        legacy_cpdetail_id,
        is_manual,
        effective_start_timestamp,
        effective_end_timestamp,
        active_flag)
select  src.cp_id,
        src.site_name,
        src.street_address,
        src.street_2,
        src.city,
        src.region,
        src.postal_code,
        src.country_id,
        src.is_active,
        src.source_org_id,
        src.source_created_at,
        src.source_updated_at,
        prev.new_street_address,
        prev.new_street_2,
        prev.new_city,
        prev.new_region,
        prev.new_postal_code,
        prev.new_country_id,
        coalesce(prev.is_primary, false),
        prev.site_comments,
        prev.legacy_cpdetail_id,
        coalesce(prev.is_manual, false),
        now(),
        cast(null as timestamptz),
        true
from    tmp_src_cp_app_cp_detail src
left join lateral (select p.* from core.cp_app_cp_detail p               -- latest previous version of the key (if any)
                   where p.cp_id = src.cp_id
                     and p.site_name = src.site_name
                   order by p.effective_start_timestamp desc, p.id desc
                   limit 1) prev on true
where   not exists (select 1 from core.cp_app_cp_detail a
                    where a.cp_id = src.cp_id
                      and a.site_name = src.site_name
                      and a.active_flag);

commit;
