-- Raw-to-core load query for core.cp_app_common_name (raw layer instead of GMDF, reference tables joined).
-- The source is reduced to one row per key first (MERGE fails when two source rows reach the same target row). PostgreSQL 15 or later.
-- Business key: source_org_id (the GMDF external party). The partner name is entered manually in the app (STTM: Manual), so it is set on insert and never overwritten.
-- partner_status_id follows the source, except for statuses that the app sets itself (ON_HOLD, INACTIVITY_WARNING): those are kept. A new status is then picked up by 12_cp_app_cp_status_history.
-- A new source partner whose name already exists under another key is skipped (unique cp_common_name), as before.
--
-- ==================== SCD TYPE 2 VERSION ====================
-- core.cp_app_common_name keeps its FULL HISTORY with the columns effective_start_timestamp, effective_end_timestamp, active_flag.
--   * changed source row  -> the ACTIVE version is CLOSED (effective_end_timestamp = now(), active_flag = false) and a NEW version is INSERTED
--                            (effective_start_timestamp = now(), effective_end_timestamp = NULL, active_flag = true);
--   * new key             -> inserted as the first version;   unchanged row -> not touched.
-- now() is fixed for the whole transaction, so the end of the closed version equals the start of the new one (no gap, no overlap).
-- Steps (one transaction): 0 snapshot of the source in a temp table | 1 MERGE closes the changed active versions | 2 INSERT the new versions.
-- Columns kept from the previous version when a new version is written (set in the app / by the pipeline, not from the source):
--   cp_common_name (entered manually), is_commercial_partner, is_vteam_partner, is_chorus_partner, primary_site_id, comments, legacy_cp_id; partner_status_id is kept when it is ON_HOLD / INACTIVITY_WARNING.
-- Joins to core tables read the ACTIVE version only (active_flag). Run 00_scd2_prerequisites.sql first (unique keys become partial: WHERE active_flag).
-- Active-version business key: (source_org_id).

begin;

-- Step 0: snapshot of the reduced source (one row per key), read once and used by steps 1 and 2.
create temp table tmp_src_cp_app_common_name on commit drop as
select z2.*
    from (
        select y.*, row_number() over (partition by y.cp_common_name order by y.source_org_id) as rn2
        from (
            select z.*
            from (
                select base.*, row_number() over (partition by base.source_org_id order by base.source_updated_at desc nulls last) as rn
                from (
                    select  coalesce(dev.name, chg.name, aud.organization_name, qms.name)  as cp_common_name,     -- STTM: Manual; the GMDF organisation name fills the NOT NULL column
                            ps.id                                   as partner_status_id,    -- ref.partner_status (lifecycle_state decoded in the join)
                            pt.id                                   as partner_type_id,      -- ref.partner_type (organisation category)
                            cast(ep.created_date as date)           as active_since_date,
                            ep.external_party_id                    as source_org_id,
                            ep.created_date                         as source_created_at,
                            ep.last_modified_date                   as source_updated_at
                    from    raw_gmdf_core_tpqm_qms.mdm_qms_external_party ep                -- GMDF view; its raw table is in the DDL (raw_gmdf_core_tpqm_qms)
                    left join raw_gmdf_core_deviation_qms.mdm_qms_organization dev
                           on dev.organization_id = ep.external_party_id and dev._is_current and not dev._source_deleted
                    left join raw_gmdf_core_change_qms.mdm_qms_organization chg
                           on chg.organization_id = ep.external_party_id and chg._is_current and not chg._source_deleted
                    left join raw_gmdf_core_aud_insp_qms.mdm_qms_organization aud
                           on aud.organization_id = ep.external_party_id and aud._is_current and not aud._source_deleted
                    left join raw_gmdf_core_complaint_qms.mdm_qms_organization qms
                           on qms.organization_id = ep.external_party_id and qms._is_current and not qms._source_deleted
                    join    ref.partner_status ps                                           -- required: partner_status_id is NOT NULL (unmapped states drop out)
                           on ps.code = case lower(trim(ep.lifecycle_state))
                                             when 'initiated' then 'PENDING_QUALIFICATION'
                                             when 'define team' then 'PENDING_QUALIFICATION'
                                             when 'in assessment' then 'PENDING_QUALIFICATION'
                                             when 'approved' then 'ACTIVE'
                                             when 'opened' then 'ACTIVE'
                                             when 'inactive' then 'INACTIVE'
                                             when 'closed - inactive' then 'INACTIVE'
                                             when 'closed - cancelled' then 'TERMINATED'
                                        end
                    left join ref.partner_type pt
                           on lower(trim(pt.code)) = lower(trim(coalesce(dev.category, chg.category, aud.category, qms.category)))
                           or lower(trim(pt.name)) = lower(trim(coalesce(dev.category, chg.category, aud.category, qms.category)))
                    where   ep._is_current and not ep._source_deleted
                      and   coalesce(dev.name, chg.name, aud.organization_name, qms.name) is not null
                ) as base (cp_common_name, partner_status_id, partner_type_id, active_since_date, source_org_id, source_created_at, source_updated_at)
            ) z
            where z.rn = 1
        ) y
    ) z2
    where z2.rn2 = 1;

-- Step 1: close the active version when a tracked column changed.
merge into core.cp_app_common_name as tgt
using tmp_src_cp_app_common_name as src
on (tgt.source_org_id = src.source_org_id
   and tgt.active_flag)
when matched and (
         (tgt.partner_status_id is distinct from src.partner_status_id
         and tgt.partner_status_id not in (select ps2.id from ref.partner_status ps2 where ps2.code in ('ON_HOLD', 'INACTIVITY_WARNING')))
      or tgt.partner_type_id is distinct from src.partner_type_id
      or tgt.active_since_date is distinct from src.active_since_date
      or tgt.source_created_at is distinct from src.source_created_at
      or tgt.source_updated_at is distinct from src.source_updated_at
     ) then
    update set effective_end_timestamp = now(),
               active_flag = false,
               updated_at = now(),
               row_version = tgt.row_version + 1;

-- Step 2: insert the new version for every key that has no active version (new keys and the keys closed in step 1).
insert into core.cp_app_common_name (
        cp_common_name,
        partner_status_id,
        partner_type_id,
        active_since_date,
        source_org_id,
        source_created_at,
        source_updated_at,
        is_commercial_partner,
        is_vteam_partner,
        is_chorus_partner,
        primary_site_id,
        comments,
        legacy_cp_id,
        effective_start_timestamp,
        effective_end_timestamp,
        active_flag)
select  case when prev.id is not null then prev.cp_common_name else src.cp_common_name end,
        case when prev.id is not null
                 and prev.partner_status_id in (select ps2.id from ref.partner_status ps2 where ps2.code in ('ON_HOLD', 'INACTIVITY_WARNING'))
                then prev.partner_status_id else src.partner_status_id end,
        src.partner_type_id,
        src.active_since_date,
        src.source_org_id,
        src.source_created_at,
        src.source_updated_at,
        prev.is_commercial_partner,
        prev.is_vteam_partner,
        prev.is_chorus_partner,
        prev.primary_site_id,
        prev.comments,
        prev.legacy_cp_id,
        now(),
        cast(null as timestamptz),
        true
from    tmp_src_cp_app_common_name src
left join lateral (select p.* from core.cp_app_common_name p               -- latest previous version of the key (if any)
                   where p.source_org_id = src.source_org_id
                   order by p.effective_start_timestamp desc, p.id desc
                   limit 1) prev on true
where   not exists (select 1 from core.cp_app_common_name a
                    where a.source_org_id = src.source_org_id
                      and a.active_flag)
  and not exists (select 1 from core.cp_app_common_name x          -- a new partner whose name is already used by another ACTIVE partner is skipped (unique cp_common_name)
                  where x.cp_common_name = src.cp_common_name and x.active_flag and x.source_org_id is distinct from src.source_org_id);

commit;
