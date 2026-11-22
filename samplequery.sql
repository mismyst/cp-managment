MERGE INTO edb_conform_bu_c360_qa.copay_claims.pharmacy_claims_fact AS tgt
USING (
        SELECT  DISTINCT
            claims.pysgn_clm_id AS pysgn_clm_id,
        claims.prgrm_desc AS prgrm_desc,
        claims.grp_nr AS grp_nr,
        claims.pat_crdhldr_id AS pat_crdhldr_id,
        claims.clm_auth AS clm_auth,
        claims.orig_clm_auth AS orig_clm_auth,
        claims.dtm_prcssd AS dtm_prcssd,
        claims.dt_prcssd AS dt_prcssd,
        claims.tm_prcssd AS tm_prcssd,
        claims.rej_flg AS rej_flg,
        claims.rev_flg AS rev_flg,
        claims.oth_cov_cd AS oth_cov_cd,
        claims.dt_flld AS dt_flld,
        claims.dt_wrttn AS dt_wrttn,
        claims.nr_rflls_auth AS nr_rflls_auth,
        claims.drug_ndc_nr AS drug_ndc_nr,
        claims.drug_nm AS drug_nm,
        claims.drug_strngth AS drug_strngth,
        claims.qty_dspnsd AS qty_dspnsd,
        claims.days_spply AS days_spply,
        claims.calc_awp AS calc_awp,
        claims.calc_wac AS calc_wac,
        claims.presc_full_nm AS presc_full_nm,
        claims.presc_frst_nm AS presc_frst_nm,
        claims.presc_lst_nm AS presc_lst_nm,
        claims.presc_dea AS presc_dea,
        claims.presc_npi AS presc_npi,
        claims.presc_addr1 AS presc_addr1,
        claims.presc_addr2 AS presc_addr2,
        claims.presc_city AS presc_city,
        claims.presc_state AS presc_state,
        claims.presc_zip AS presc_zip,
        claims.presc_cred AS presc_cred,
        claims.presc_typ AS presc_typ,
        claims.presc_spec1 AS presc_spec1,
        claims.presc_spec2 AS presc_spec2,
        claims.pharm_npi AS pharm_npi,
        claims.pharm_ncpdp_id AS pharm_ncpdp_id,
        claims.pharm_nm AS pharm_nm,
        claims.pharm_chain_nr AS pharm_chain_nr,
        claims.pharm_chain_nm AS pharm_chain_nm,
        claims.pharm_addr1 AS pharm_addr1,
        claims.pharm_addr2 AS pharm_addr2,
        claims.pharm_city AS pharm_city,
        claims.pharm_state AS pharm_state,
        claims.pharm_zip AS pharm_zip,
        claims.pat_init_oop AS pat_init_oop,
        claims.paid_bnft AS paid_bnft,
        claims.tot_pat_pay_amt AS tot_pat_pay_amt,
        claims.rej_cd AS rej_cd,
        claims.rej_desc AS rej_desc,
        claims.prmry_pyr_bin AS prmry_pyr_bin,
        claims.txn_stts AS txn_stts,
        claims.rx_nr AS rx_nr,
        claims.fill_nr AS fill_nr,
        claims.drug_dose AS drug_dose,
        claims.sub_comp_cd AS sub_comp_cd,
        claims.daw_cd AS daw_cd,
        claims.coupon_act_use_nr AS coupon_act_use_nr,
        claims.plan_dis_fee AS plan_dis_fee,
        claims.plan_sales_tax AS plan_sales_tax,
        claims.prmry_pyr_rej1 AS prmry_pyr_rej1,
        claims.prmry_pyr_rej2 AS prmry_pyr_rej2,
        claims.prmry_pyr_rej3 AS prmry_pyr_rej3,
        claims.clm_prgrm_typ AS clm_prgrm_typ,
        claims.cov_typ AS cov_typ,
        claims.ann_cap_max_reach_dt AS ann_cap_max_reach_dt,
        claims.clm_load_dt AS clm_load_dt,
        medben.med_clm_sub_id AS med_clm_sub_id,
        medben.clm_id AS clm_id,
        medben.clm_sub_dt AS clm_sub_dt,
        medben.medben_prgrm_id AS medben_prgrm_id,
        medben.med_clm_amt AS med_clm_amt,
        medben.clm_stts AS clm_stts,
        medben.svc_dt_from AS svc_dt_from,
        medben.svc_dt_to AS svc_dt_to,
        medben.insrd_id_nr AS insrd_id_nr,
        medben.oth_insrd_grp_nr AS oth_insrd_grp_nr,
        medben.oth_ins_pln_nm AS oth_ins_pln_nm,
        medben.insrd_grp_nr AS insrd_grp_nr,
        medben.ins_pln_nm AS ins_pln_nm,
        medben.oth_hlth_bnft_pln AS oth_hlth_bnft_pln,
        medben.curr_illness_dt AS curr_illness_dt,
        medben.diag_cd AS diag_cd,
        medben.svc_dt AS svc_dt,
        medben.plc_of_svc AS plc_of_svc,
        medben.cpt_hcpcs AS cpt_hcpcs,
        medben.ndc AS ndc,
        medben.diag_ptr AS diag_ptr,
        medben.chrgs AS chrgs,
        medben.unts_days AS unts_days,
        medben.prscrbr_npi AS prscrbr_npi,
        medben.fed_tax_id AS fed_tax_id,
        medben.svc_fac_loc_info AS svc_fac_loc_info,
        medben.bill_prov_info AS bill_prov_info,
        medben.clm_log_nr AS clm_log_nr,
        medben.clm_log_stts AS clm_log_stts,
        medben.clm_log_dt AS clm_log_dt,
        medben.rej_rsn AS rej_rsn,
        medben.rej_level AS rej_level,
        medben.pmt_stts_dt AS pmt_stts_dt,
        medben.pmt_typ AS pmt_typ,
        medben.pmt_stts AS pmt_stts,
        medben.pmt_amt AS pmt_amt,
        DATE_FORMAT(claims.clm_load_dt,'yyyy-MM') AS src_crtd_yr_mnth,
        'Paysign' AS etl_src_id,
        NULL AS etl_src_rec_id,
        NULL AS src_dt,
        CURRENT_DATE() AS crtd_dt,
        'SYSTEM' AS crtd_by,
        CURRENT_DATE() AS updt_dt,
        'SYSTEM' AS updt_by,
        CURRENT_TIMESTAMP() AS etl_dt,
        CURRENT_DATE() AS eff_strt_dt,
        DATE '9999-12-31' AS eff_end_dt,
        CURRENT_TIMESTAMP() AS lst_updt_ts,
        TRUE AS is_actv,
        'I' AS opn_flg,
        Null AS ext_fld_1,
        1049524890693005 as etl_job_id
        FROM edb_conform_bu_c360_qa.copay_claims.claims_fact AS claims
    left join edb_conform_bu_c360_qa.copay_claims.medben_claims_combined_dim as medben on medben.pat_crdhldr_id = claims.pat_crdhldr_id AND medben.is_actv = TRUE
 WHERE  GREATEST( claims.lst_updt_ts , medben.lst_updt_ts) >= (SELECT COALESCE(MAX(lst_run_ts), CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_qa.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'pharmacy_claims_fact' AND schm_nm = 'copay_claims' and src_system = 'LSC')  AND claims.is_actv=TRUE 
        ) AS src
ON
    tgt.pysgn_clm_id <=> src.pysgn_clm_id AND
    tgt.cpt_hcpcs <=> src.cpt_hcpcs AND
    tgt.clm_log_nr <=> src.clm_log_nr AND
    tgt.is_actv = TRUE
WHEN MATCHED AND (
    COALESCE(tgt.prgrm_desc, '') <> COALESCE(src.prgrm_desc, '') OR
    COALESCE(tgt.grp_nr, '') <> COALESCE(src.grp_nr, '') OR
    COALESCE(tgt.pat_crdhldr_id, '') <> COALESCE(src.pat_crdhldr_id, '') OR
    COALESCE(tgt.clm_auth, '') <> COALESCE(src.clm_auth, '') OR
    COALESCE(tgt.orig_clm_auth, '') <> COALESCE(src.orig_clm_auth, '') OR
    COALESCE(tgt.dtm_prcssd, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.dtm_prcssd, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.dt_prcssd, '') <> COALESCE(src.dt_prcssd, '') OR
    COALESCE(tgt.tm_prcssd, '') <> COALESCE(src.tm_prcssd, '') OR
    COALESCE(tgt.rej_flg, 0) <> COALESCE(src.rej_flg, 0) OR
    COALESCE(tgt.rev_flg, 0) <> COALESCE(src.rev_flg, 0) OR
    COALESCE(tgt.oth_cov_cd, 0) <> COALESCE(src.oth_cov_cd, 0) OR
    COALESCE(tgt.dt_flld, '') <> COALESCE(src.dt_flld, '') OR
    COALESCE(tgt.dt_wrttn, '') <> COALESCE(src.dt_wrttn, '') OR
    COALESCE(tgt.nr_rflls_auth, 0) <> COALESCE(src.nr_rflls_auth, 0) OR
    COALESCE(tgt.drug_ndc_nr, 0.0) <> COALESCE(src.drug_ndc_nr, 0.0) OR
    COALESCE(tgt.drug_nm, '') <> COALESCE(src.drug_nm, '') OR
    COALESCE(tgt.drug_strngth, '') <> COALESCE(src.drug_strngth, '') OR
    COALESCE(tgt.qty_dspnsd, 0.0) <> COALESCE(src.qty_dspnsd, 0.0) OR
    COALESCE(tgt.days_spply, 0.0) <> COALESCE(src.days_spply, 0.0) OR
    COALESCE(tgt.calc_awp, 0.0) <> COALESCE(src.calc_awp, 0.0) OR
    COALESCE(tgt.calc_wac, 0.0) <> COALESCE(src.calc_wac, 0.0) OR
    COALESCE(tgt.presc_full_nm, '') <> COALESCE(src.presc_full_nm, '') OR
    COALESCE(tgt.presc_frst_nm, '') <> COALESCE(src.presc_frst_nm, '') OR
    COALESCE(tgt.presc_lst_nm, '') <> COALESCE(src.presc_lst_nm, '') OR
    COALESCE(tgt.presc_dea, '') <> COALESCE(src.presc_dea, '') OR
    COALESCE(tgt.presc_npi, 0) <> COALESCE(src.presc_npi, 0) OR
    COALESCE(tgt.presc_addr1, '') <> COALESCE(src.presc_addr1, '') OR
    COALESCE(tgt.presc_addr2, '') <> COALESCE(src.presc_addr2, '') OR
    COALESCE(tgt.presc_city, '') <> COALESCE(src.presc_city, '') OR
    COALESCE(tgt.presc_state, '') <> COALESCE(src.presc_state, '') OR
    COALESCE(tgt.presc_zip, 0.0) <> COALESCE(src.presc_zip, 0.0) OR
    COALESCE(tgt.presc_cred, '') <> COALESCE(src.presc_cred, '') OR
    COALESCE(tgt.presc_typ, '') <> COALESCE(src.presc_typ, '') OR
    COALESCE(tgt.presc_spec1, '') <> COALESCE(src.presc_spec1, '') OR
    COALESCE(tgt.presc_spec2, '') <> COALESCE(src.presc_spec2, '') OR
    COALESCE(tgt.pharm_npi, 0) <> COALESCE(src.pharm_npi, 0) OR
    COALESCE(tgt.pharm_ncpdp_id, 0) <> COALESCE(src.pharm_ncpdp_id, 0) OR
    COALESCE(tgt.pharm_nm, '') <> COALESCE(src.pharm_nm, '') OR
    COALESCE(tgt.pharm_chain_nr, '') <> COALESCE(src.pharm_chain_nr, '') OR
    COALESCE(tgt.pharm_chain_nm, '') <> COALESCE(src.pharm_chain_nm, '') OR
    COALESCE(tgt.pharm_addr1, '') <> COALESCE(src.pharm_addr1, '') OR
    COALESCE(tgt.pharm_addr2, '') <> COALESCE(src.pharm_addr2, '') OR
    COALESCE(tgt.pharm_city, '') <> COALESCE(src.pharm_city, '') OR
    COALESCE(tgt.pharm_state, '') <> COALESCE(src.pharm_state, '') OR
    COALESCE(tgt.pharm_zip, 0) <> COALESCE(src.pharm_zip, 0) OR
    COALESCE(tgt.pat_init_oop, 0.0) <> COALESCE(src.pat_init_oop, 0.0) OR
    COALESCE(tgt.paid_bnft, 0.0) <> COALESCE(src.paid_bnft, 0.0) OR
    COALESCE(tgt.tot_pat_pay_amt, 0.0) <> COALESCE(src.tot_pat_pay_amt, 0.0) OR
    COALESCE(tgt.rej_cd, '') <> COALESCE(src.rej_cd, '') OR
    COALESCE(tgt.rej_desc, '') <> COALESCE(src.rej_desc, '') OR
    COALESCE(tgt.prmry_pyr_bin, '') <> COALESCE(src.prmry_pyr_bin, '') OR
    COALESCE(tgt.txn_stts, '') <> COALESCE(src.txn_stts, '') OR
    COALESCE(tgt.rx_nr, '') <> COALESCE(src.rx_nr, '') OR
    COALESCE(tgt.fill_nr, 0) <> COALESCE(src.fill_nr, 0) OR
    COALESCE(tgt.drug_dose, '') <> COALESCE(src.drug_dose, '') OR
    COALESCE(tgt.sub_comp_cd, 0) <> COALESCE(src.sub_comp_cd, 0) OR
    COALESCE(tgt.daw_cd, 0) <> COALESCE(src.daw_cd, 0) OR
    COALESCE(tgt.coupon_act_use_nr, 0) <> COALESCE(src.coupon_act_use_nr, 0) OR
    COALESCE(tgt.plan_dis_fee, 0.0) <> COALESCE(src.plan_dis_fee, 0.0) OR
    COALESCE(tgt.plan_sales_tax, 0.0) <> COALESCE(src.plan_sales_tax, 0.0) OR
    COALESCE(tgt.prmry_pyr_rej1, '') <> COALESCE(src.prmry_pyr_rej1, '') OR
    COALESCE(tgt.prmry_pyr_rej2, '') <> COALESCE(src.prmry_pyr_rej2, '') OR
    COALESCE(tgt.prmry_pyr_rej3, '') <> COALESCE(src.prmry_pyr_rej3, '') OR
    COALESCE(tgt.clm_prgrm_typ, '') <> COALESCE(src.clm_prgrm_typ, '') OR
    COALESCE(tgt.cov_typ, '') <> COALESCE(src.cov_typ, '') OR
    COALESCE(tgt.ann_cap_max_reach_dt, '') <> COALESCE(src.ann_cap_max_reach_dt, '') OR
    COALESCE(tgt.clm_load_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_load_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.med_clm_sub_id, 0.0) <> COALESCE(src.med_clm_sub_id, 0.0) OR
    COALESCE(tgt.clm_id, '') <> COALESCE(src.clm_id, '') OR
    COALESCE(tgt.clm_sub_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_sub_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.medben_prgrm_id, 0) <> COALESCE(src.medben_prgrm_id, 0) OR
    COALESCE(tgt.med_clm_amt, 0.0) <> COALESCE(src.med_clm_amt, 0.0) OR
    COALESCE(tgt.clm_stts, '') <> COALESCE(src.clm_stts, '') OR
    COALESCE(tgt.svc_dt_from, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt_from, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.svc_dt_to, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt_to, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.insrd_id_nr, '') <> COALESCE(src.insrd_id_nr, '') OR
    COALESCE(tgt.oth_insrd_grp_nr, '') <> COALESCE(src.oth_insrd_grp_nr, '') OR
    COALESCE(tgt.oth_ins_pln_nm, '') <> COALESCE(src.oth_ins_pln_nm, '') OR
    COALESCE(tgt.insrd_grp_nr, '') <> COALESCE(src.insrd_grp_nr, '') OR
    COALESCE(tgt.ins_pln_nm, '') <> COALESCE(src.ins_pln_nm, '') OR
    COALESCE(tgt.oth_hlth_bnft_pln, 0) <> COALESCE(src.oth_hlth_bnft_pln, 0) OR
    COALESCE(tgt.curr_illness_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.curr_illness_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.diag_cd, '') <> COALESCE(src.diag_cd, '') OR
    COALESCE(tgt.svc_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.plc_of_svc, '') <> COALESCE(src.plc_of_svc, '') OR
    COALESCE(tgt.ndc, '') <> COALESCE(src.ndc, '') OR
    COALESCE(tgt.diag_ptr, '') <> COALESCE(src.diag_ptr, '') OR
    COALESCE(tgt.chrgs, 0.0) <> COALESCE(src.chrgs, 0.0) OR
    COALESCE(tgt.unts_days, 0) <> COALESCE(src.unts_days, 0) OR
    COALESCE(tgt.prscrbr_npi, 0.0) <> COALESCE(src.prscrbr_npi, 0.0) OR
    COALESCE(tgt.fed_tax_id, 0.0) <> COALESCE(src.fed_tax_id, 0.0) OR
    COALESCE(tgt.svc_fac_loc_info, '') <> COALESCE(src.svc_fac_loc_info, '') OR
    COALESCE(tgt.bill_prov_info, '') <> COALESCE(src.bill_prov_info, '') OR
    COALESCE(tgt.clm_log_stts, '') <> COALESCE(src.clm_log_stts, '') OR
    COALESCE(tgt.clm_log_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_log_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.rej_rsn, '') <> COALESCE(src.rej_rsn, '') OR
    COALESCE(tgt.rej_level, '') <> COALESCE(src.rej_level, '') OR
    COALESCE(tgt.pmt_stts_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.pmt_stts_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.pmt_typ, '') <> COALESCE(src.pmt_typ, '') OR
    COALESCE(tgt.pmt_stts, '') <> COALESCE(src.pmt_stts, '') OR
    COALESCE(tgt.pmt_amt, 0.0) <> COALESCE(src.pmt_amt, 0.0) OR
    COALESCE(tgt.src_crtd_yr_mnth, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.src_crtd_yr_mnth, CAST('1900-01-01 00:00:00' AS TIMESTAMP))
) THEN
    UPDATE SET
        eff_end_dt = CURRENT_DATE(),
        is_actv = FALSE,
        lst_updt_ts = CURRENT_TIMESTAMP(),
        updt_dt = CURRENT_DATE(),
        updt_by = 'SYSTEM',
        etl_job_id = '1049524890693005'
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        pysgn_clm_id,
        prgrm_desc,
        grp_nr,
        pat_crdhldr_id,
        clm_auth,
        orig_clm_auth,
        dtm_prcssd,
        dt_prcssd,
        tm_prcssd,
        rej_flg,
        rev_flg,
        oth_cov_cd,
        dt_flld,
        dt_wrttn,
        nr_rflls_auth,
        drug_ndc_nr,
        drug_nm,
        drug_strngth,
        qty_dspnsd,
        days_spply,
        calc_awp,
        calc_wac,
        presc_full_nm,
        presc_frst_nm,
        presc_lst_nm,
        presc_dea,
        presc_npi,
        presc_addr1,
        presc_addr2,
        presc_city,
        presc_state,
        presc_zip,
        presc_cred,
        presc_typ,
        presc_spec1,
        presc_spec2,
        pharm_npi,
        pharm_ncpdp_id,
        pharm_nm,
        pharm_chain_nr,
        pharm_chain_nm,
        pharm_addr1,
        pharm_addr2,
        pharm_city,
        pharm_state,
        pharm_zip,
        pat_init_oop,
        paid_bnft,
        tot_pat_pay_amt,
        rej_cd,
        rej_desc,
        prmry_pyr_bin,
        txn_stts,
        rx_nr,
        fill_nr,
        drug_dose,
        sub_comp_cd,
        daw_cd,
        coupon_act_use_nr,
        plan_dis_fee,
        plan_sales_tax,
        prmry_pyr_rej1,
        prmry_pyr_rej2,
        prmry_pyr_rej3,
        clm_prgrm_typ,
        cov_typ,
        ann_cap_max_reach_dt,
        clm_load_dt,
        med_clm_sub_id,
        clm_id,
        clm_sub_dt,
        medben_prgrm_id,
        med_clm_amt,
        clm_stts,
        svc_dt_from,
        svc_dt_to,
        insrd_id_nr,
        oth_insrd_grp_nr,
        oth_ins_pln_nm,
        insrd_grp_nr,
        ins_pln_nm,
        oth_hlth_bnft_pln,
        curr_illness_dt,
        diag_cd,
        svc_dt,
        plc_of_svc,
        cpt_hcpcs,
        ndc,
        diag_ptr,
        chrgs,
        unts_days,
        prscrbr_npi,
        fed_tax_id,
        svc_fac_loc_info,
        bill_prov_info,
        clm_log_nr,
        clm_log_stts,
        clm_log_dt,
        rej_rsn,
        rej_level,
        pmt_stts_dt,
        pmt_typ,
        pmt_stts,
        pmt_amt,
        src_crtd_yr_mnth,
        etl_src_id,
        etl_src_rec_id,
        src_dt,
        crtd_dt,
        crtd_by,
        updt_dt,
        updt_by,
        etl_dt,
        eff_strt_dt,
        eff_end_dt,
        lst_updt_ts,
        is_actv,
        opn_flg,
        ext_fld_1,
        etl_job_id
    )
    VALUES (
        src.pysgn_clm_id,
        src.prgrm_desc,
        src.grp_nr,
        src.pat_crdhldr_id,
        src.clm_auth,
        src.orig_clm_auth,
        src.dtm_prcssd,
        src.dt_prcssd,
        src.tm_prcssd,
        src.rej_flg,
        src.rev_flg,
        src.oth_cov_cd,
        src.dt_flld,
        src.dt_wrttn,
        src.nr_rflls_auth,
        src.drug_ndc_nr,
        src.drug_nm,
        src.drug_strngth,
        src.qty_dspnsd,
        src.days_spply,
        src.calc_awp,
        src.calc_wac,
        src.presc_full_nm,
        src.presc_frst_nm,
        src.presc_lst_nm,
        src.presc_dea,
        src.presc_npi,
        src.presc_addr1,
        src.presc_addr2,
        src.presc_city,
        src.presc_state,
        src.presc_zip,
        src.presc_cred,
        src.presc_typ,
        src.presc_spec1,
        src.presc_spec2,
        src.pharm_npi,
        src.pharm_ncpdp_id,
        src.pharm_nm,
        src.pharm_chain_nr,
        src.pharm_chain_nm,
        src.pharm_addr1,
        src.pharm_addr2,
        src.pharm_city,
        src.pharm_state,
        src.pharm_zip,
        src.pat_init_oop,
        src.paid_bnft,
        src.tot_pat_pay_amt,
        src.rej_cd,
        src.rej_desc,
        src.prmry_pyr_bin,
        src.txn_stts,
        src.rx_nr,
        src.fill_nr,
        src.drug_dose,
        src.sub_comp_cd,
        src.daw_cd,
        src.coupon_act_use_nr,
        src.plan_dis_fee,
        src.plan_sales_tax,
        src.prmry_pyr_rej1,
        src.prmry_pyr_rej2,
        src.prmry_pyr_rej3,
        src.clm_prgrm_typ,
        src.cov_typ,
        src.ann_cap_max_reach_dt,
        src.clm_load_dt,
        src.med_clm_sub_id,
        src.clm_id,
        src.clm_sub_dt,
        src.medben_prgrm_id,
        src.med_clm_amt,
        src.clm_stts,
        src.svc_dt_from,
        src.svc_dt_to,
        src.insrd_id_nr,
        src.oth_insrd_grp_nr,
        src.oth_ins_pln_nm,
        src.insrd_grp_nr,
        src.ins_pln_nm,
        src.oth_hlth_bnft_pln,
        src.curr_illness_dt,
        src.diag_cd,
        src.svc_dt,
        src.plc_of_svc,
        src.cpt_hcpcs,
        src.ndc,
        src.diag_ptr,
        src.chrgs,
        src.unts_days,
        src.prscrbr_npi,
        src.fed_tax_id,
        src.svc_fac_loc_info,
        src.bill_prov_info,
        src.clm_log_nr,
        src.clm_log_stts,
        src.clm_log_dt,
        src.rej_rsn,
        src.rej_level,
        src.pmt_stts_dt,
        src.pmt_typ,
        src.pmt_stts,
        src.pmt_amt,
        src.src_crtd_yr_mnth,
        src.etl_src_id,
        src.etl_src_rec_id,
        src.src_dt,
        src.crtd_dt,
        src.crtd_by,
        src.updt_dt,
        src.updt_by,
        src.etl_dt,
        src.eff_strt_dt,
        src.eff_end_dt,
        src.lst_updt_ts,
        src.is_actv,
        src.opn_flg,
        src.ext_fld_1,
        src.etl_job_id
    );
	
	
	
	
	INSERT INTO edb_conform_bu_c360_qa.copay_claims.pharmacy_claims_fact (
            pysgn_clm_id, prgrm_desc, grp_nr, pat_crdhldr_id, clm_auth, orig_clm_auth, dtm_prcssd, dt_prcssd, tm_prcssd, rej_flg, rev_flg, oth_cov_cd, dt_flld, dt_wrttn, nr_rflls_auth, drug_ndc_nr, drug_nm, drug_strngth, qty_dspnsd, days_spply, calc_awp, calc_wac, presc_full_nm, presc_frst_nm, presc_lst_nm, presc_dea, presc_npi, presc_addr1, presc_addr2, presc_city, presc_state, presc_zip, presc_cred, presc_typ, presc_spec1, presc_spec2, pharm_npi, pharm_ncpdp_id, pharm_nm, pharm_chain_nr, pharm_chain_nm, pharm_addr1, pharm_addr2, pharm_city, pharm_state, pharm_zip, pat_init_oop, paid_bnft, tot_pat_pay_amt, rej_cd, rej_desc, prmry_pyr_bin, txn_stts, rx_nr, fill_nr, drug_dose, sub_comp_cd, daw_cd, coupon_act_use_nr, plan_dis_fee, plan_sales_tax, prmry_pyr_rej1, prmry_pyr_rej2, prmry_pyr_rej3, clm_prgrm_typ, cov_typ, ann_cap_max_reach_dt, clm_load_dt, med_clm_sub_id, clm_id, clm_sub_dt, medben_prgrm_id, med_clm_amt, clm_stts, svc_dt_from, svc_dt_to, insrd_id_nr, oth_insrd_grp_nr, oth_ins_pln_nm, insrd_grp_nr, ins_pln_nm, oth_hlth_bnft_pln, curr_illness_dt, diag_cd, svc_dt, plc_of_svc, cpt_hcpcs, ndc, diag_ptr, chrgs, unts_days, prscrbr_npi, fed_tax_id, svc_fac_loc_info, bill_prov_info, clm_log_nr, clm_log_stts, clm_log_dt, rej_rsn, rej_level, pmt_stts_dt, pmt_typ, pmt_stts, pmt_amt, src_crtd_yr_mnth, etl_src_id, etl_src_rec_id, src_dt, crtd_dt, crtd_by, updt_dt, updt_by, etl_dt, eff_strt_dt, eff_end_dt, lst_updt_ts, is_actv, opn_flg, ext_fld_1, etl_job_id
        )
        SELECT src.pysgn_clm_id, src.prgrm_desc, src.grp_nr, src.pat_crdhldr_id, src.clm_auth, src.orig_clm_auth, src.dtm_prcssd, src.dt_prcssd, src.tm_prcssd, src.rej_flg, src.rev_flg, src.oth_cov_cd, src.dt_flld, src.dt_wrttn, src.nr_rflls_auth, src.drug_ndc_nr, src.drug_nm, src.drug_strngth, src.qty_dspnsd, src.days_spply, src.calc_awp, src.calc_wac, src.presc_full_nm, src.presc_frst_nm, src.presc_lst_nm, src.presc_dea, src.presc_npi, src.presc_addr1, src.presc_addr2, src.presc_city, src.presc_state, src.presc_zip, src.presc_cred, src.presc_typ, src.presc_spec1, src.presc_spec2, src.pharm_npi, src.pharm_ncpdp_id, src.pharm_nm, src.pharm_chain_nr, src.pharm_chain_nm, src.pharm_addr1, src.pharm_addr2, src.pharm_city, src.pharm_state, src.pharm_zip, src.pat_init_oop, src.paid_bnft, src.tot_pat_pay_amt, src.rej_cd, src.rej_desc, src.prmry_pyr_bin, src.txn_stts, src.rx_nr, src.fill_nr, src.drug_dose, src.sub_comp_cd, src.daw_cd, src.coupon_act_use_nr, src.plan_dis_fee, src.plan_sales_tax, src.prmry_pyr_rej1, src.prmry_pyr_rej2, src.prmry_pyr_rej3, src.clm_prgrm_typ, src.cov_typ, src.ann_cap_max_reach_dt, src.clm_load_dt, src.med_clm_sub_id, src.clm_id, src.clm_sub_dt, src.medben_prgrm_id, src.med_clm_amt, src.clm_stts, src.svc_dt_from, src.svc_dt_to, src.insrd_id_nr, src.oth_insrd_grp_nr, src.oth_ins_pln_nm, src.insrd_grp_nr, src.ins_pln_nm, src.oth_hlth_bnft_pln, src.curr_illness_dt, src.diag_cd, src.svc_dt, src.plc_of_svc, src.cpt_hcpcs, src.ndc, src.diag_ptr, src.chrgs, src.unts_days, src.prscrbr_npi, src.fed_tax_id, src.svc_fac_loc_info, src.bill_prov_info, src.clm_log_nr, src.clm_log_stts, src.clm_log_dt, src.rej_rsn, src.rej_level, src.pmt_stts_dt, src.pmt_typ, src.pmt_stts, src.pmt_amt, src.src_crtd_yr_mnth, src.etl_src_id, src.etl_src_rec_id, src.src_dt, src.crtd_dt, src.crtd_by, src.updt_dt, src.updt_by, src.etl_dt, src.eff_strt_dt, src.eff_end_dt, src.lst_updt_ts, src.is_actv, src.opn_flg, src.ext_fld_1, src.etl_job_id FROM (Select DISTINCT   claims.pysgn_clm_id AS pysgn_clm_id,
    claims.prgrm_desc AS prgrm_desc,
    claims.grp_nr AS grp_nr,
    claims.pat_crdhldr_id AS pat_crdhldr_id,
    claims.clm_auth AS clm_auth,
    claims.orig_clm_auth AS orig_clm_auth,
    claims.dtm_prcssd AS dtm_prcssd,
    claims.dt_prcssd AS dt_prcssd,
    claims.tm_prcssd AS tm_prcssd,
    claims.rej_flg AS rej_flg,
    claims.rev_flg AS rev_flg,
    claims.oth_cov_cd AS oth_cov_cd,
    claims.dt_flld AS dt_flld,
    claims.dt_wrttn AS dt_wrttn,
    claims.nr_rflls_auth AS nr_rflls_auth,
    claims.drug_ndc_nr AS drug_ndc_nr,
    claims.drug_nm AS drug_nm,
    claims.drug_strngth AS drug_strngth,
    claims.qty_dspnsd AS qty_dspnsd,
    claims.days_spply AS days_spply,
    claims.calc_awp AS calc_awp,
    claims.calc_wac AS calc_wac,
    claims.presc_full_nm AS presc_full_nm,
    claims.presc_frst_nm AS presc_frst_nm,
    claims.presc_lst_nm AS presc_lst_nm,
    claims.presc_dea AS presc_dea,
    claims.presc_npi AS presc_npi,
    claims.presc_addr1 AS presc_addr1,
    claims.presc_addr2 AS presc_addr2,
    claims.presc_city AS presc_city,
    claims.presc_state AS presc_state,
    claims.presc_zip AS presc_zip,
    claims.presc_cred AS presc_cred,
    claims.presc_typ AS presc_typ,
    claims.presc_spec1 AS presc_spec1,
    claims.presc_spec2 AS presc_spec2,
    claims.pharm_npi AS pharm_npi,
    claims.pharm_ncpdp_id AS pharm_ncpdp_id,
    claims.pharm_nm AS pharm_nm,
    claims.pharm_chain_nr AS pharm_chain_nr,
    claims.pharm_chain_nm AS pharm_chain_nm,
    claims.pharm_addr1 AS pharm_addr1,
    claims.pharm_addr2 AS pharm_addr2,
    claims.pharm_city AS pharm_city,
    claims.pharm_state AS pharm_state,
    claims.pharm_zip AS pharm_zip,
    claims.pat_init_oop AS pat_init_oop,
    claims.paid_bnft AS paid_bnft,
    claims.tot_pat_pay_amt AS tot_pat_pay_amt,
    claims.rej_cd AS rej_cd,
    claims.rej_desc AS rej_desc,
    claims.prmry_pyr_bin AS prmry_pyr_bin,
    claims.txn_stts AS txn_stts,
    claims.rx_nr AS rx_nr,
    claims.fill_nr AS fill_nr,
    claims.drug_dose AS drug_dose,
    claims.sub_comp_cd AS sub_comp_cd,
    claims.daw_cd AS daw_cd,
    claims.coupon_act_use_nr AS coupon_act_use_nr,
    claims.plan_dis_fee AS plan_dis_fee,
    claims.plan_sales_tax AS plan_sales_tax,
    claims.prmry_pyr_rej1 AS prmry_pyr_rej1,
    claims.prmry_pyr_rej2 AS prmry_pyr_rej2,
    claims.prmry_pyr_rej3 AS prmry_pyr_rej3,
    claims.clm_prgrm_typ AS clm_prgrm_typ,
    claims.cov_typ AS cov_typ,
    claims.ann_cap_max_reach_dt AS ann_cap_max_reach_dt,
    claims.clm_load_dt AS clm_load_dt,
    medben.med_clm_sub_id AS med_clm_sub_id,
    medben.clm_id AS clm_id,
    medben.clm_sub_dt AS clm_sub_dt,
    medben.medben_prgrm_id AS medben_prgrm_id,
    medben.med_clm_amt AS med_clm_amt,
    medben.clm_stts AS clm_stts,
    medben.svc_dt_from AS svc_dt_from,
    medben.svc_dt_to AS svc_dt_to,
    medben.insrd_id_nr AS insrd_id_nr,
    medben.oth_insrd_grp_nr AS oth_insrd_grp_nr,
    medben.oth_ins_pln_nm AS oth_ins_pln_nm,
    medben.insrd_grp_nr AS insrd_grp_nr,
    medben.ins_pln_nm AS ins_pln_nm,
    medben.oth_hlth_bnft_pln AS oth_hlth_bnft_pln,
    medben.curr_illness_dt AS curr_illness_dt,
    medben.diag_cd AS diag_cd,
    medben.svc_dt AS svc_dt,
    medben.plc_of_svc AS plc_of_svc,
    medben.cpt_hcpcs AS cpt_hcpcs,
    medben.ndc AS ndc,
    medben.diag_ptr AS diag_ptr,
    medben.chrgs AS chrgs,
    medben.unts_days AS unts_days,
    medben.prscrbr_npi AS prscrbr_npi,
    medben.fed_tax_id AS fed_tax_id,
    medben.svc_fac_loc_info AS svc_fac_loc_info,
    medben.bill_prov_info AS bill_prov_info,
    medben.clm_log_nr AS clm_log_nr,
    medben.clm_log_stts AS clm_log_stts,
    medben.clm_log_dt AS clm_log_dt,
    medben.rej_rsn AS rej_rsn,
    medben.rej_level AS rej_level,
    medben.pmt_stts_dt AS pmt_stts_dt,
    medben.pmt_typ AS pmt_typ,
    medben.pmt_stts AS pmt_stts,
    medben.pmt_amt AS pmt_amt,
    DATE_FORMAT(claims.clm_load_dt,'yyyy-MM') AS src_crtd_yr_mnth,
    'Paysign' AS etl_src_id,
    NULL AS etl_src_rec_id,
    NULL AS src_dt,
    CURRENT_DATE() AS crtd_dt,
    'SYSTEM' AS crtd_by,
    CURRENT_DATE() AS updt_dt,
    'SYSTEM' AS updt_by,
    CURRENT_TIMESTAMP() AS etl_dt,
    CURRENT_DATE() AS eff_strt_dt,
    DATE '9999-12-31' AS eff_end_dt,
    CURRENT_TIMESTAMP() AS lst_updt_ts,
    TRUE AS is_actv,
    'U' AS opn_flg,
    Null AS ext_fld_1,
    1049524890693005 as etl_job_id
                FROM edb_conform_bu_c360_qa.copay_claims.claims_fact AS claims
                
left join edb_conform_bu_c360_qa.copay_claims.medben_claims_combined_dim as medben on medben.pat_crdhldr_id = claims.pat_crdhldr_id AND medben.is_actv = TRUE where claims.is_actv=TRUE ) AS src
        LEFT JOIN edb_conform_bu_c360_qa.copay_claims.pharmacy_claims_fact AS tgt
        ON
            tgt.pysgn_clm_id <=> src.pysgn_clm_id AND
    tgt.cpt_hcpcs <=> src.cpt_hcpcs AND
    tgt.clm_log_nr <=> src.clm_log_nr
        WHERE
         tgt.lst_updt_ts between (SELECT COALESCE(MAX(lst_run_ts), CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_qa.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'pharmacy_claims_fact' AND schm_nm = 'copay_claims' and src_system = 'LSC') and CURRENT_TIMESTAMP()     
            AND tgt.is_actv = FALSE
            and tgt.etl_job_id = '1049524890693005'
            AND (
                COALESCE(tgt.prgrm_desc, '') <> COALESCE(src.prgrm_desc, '') OR
    COALESCE(tgt.grp_nr, '') <> COALESCE(src.grp_nr, '') OR
    COALESCE(tgt.pat_crdhldr_id, '') <> COALESCE(src.pat_crdhldr_id, '') OR
    COALESCE(tgt.clm_auth, '') <> COALESCE(src.clm_auth, '') OR
    COALESCE(tgt.orig_clm_auth, '') <> COALESCE(src.orig_clm_auth, '') OR
    COALESCE(tgt.dtm_prcssd, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.dtm_prcssd, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.dt_prcssd, '') <> COALESCE(src.dt_prcssd, '') OR
    COALESCE(tgt.tm_prcssd, '') <> COALESCE(src.tm_prcssd, '') OR
    COALESCE(tgt.rej_flg, 0) <> COALESCE(src.rej_flg, 0) OR
    COALESCE(tgt.rev_flg, 0) <> COALESCE(src.rev_flg, 0) OR
    COALESCE(tgt.oth_cov_cd, 0) <> COALESCE(src.oth_cov_cd, 0) OR
    COALESCE(tgt.dt_flld, '') <> COALESCE(src.dt_flld, '') OR
    COALESCE(tgt.dt_wrttn, '') <> COALESCE(src.dt_wrttn, '') OR
    COALESCE(tgt.nr_rflls_auth, 0) <> COALESCE(src.nr_rflls_auth, 0) OR
    COALESCE(tgt.drug_ndc_nr, 0.0) <> COALESCE(src.drug_ndc_nr, 0.0) OR
    COALESCE(tgt.drug_nm, '') <> COALESCE(src.drug_nm, '') OR
    COALESCE(tgt.drug_strngth, '') <> COALESCE(src.drug_strngth, '') OR
    COALESCE(tgt.qty_dspnsd, 0.0) <> COALESCE(src.qty_dspnsd, 0.0) OR
    COALESCE(tgt.days_spply, 0.0) <> COALESCE(src.days_spply, 0.0) OR
    COALESCE(tgt.calc_awp, 0.0) <> COALESCE(src.calc_awp, 0.0) OR
    COALESCE(tgt.calc_wac, 0.0) <> COALESCE(src.calc_wac, 0.0) OR
    COALESCE(tgt.presc_full_nm, '') <> COALESCE(src.presc_full_nm, '') OR
    COALESCE(tgt.presc_frst_nm, '') <> COALESCE(src.presc_frst_nm, '') OR
    COALESCE(tgt.presc_lst_nm, '') <> COALESCE(src.presc_lst_nm, '') OR
    COALESCE(tgt.presc_dea, '') <> COALESCE(src.presc_dea, '') OR
    COALESCE(tgt.presc_npi, 0) <> COALESCE(src.presc_npi, 0) OR
    COALESCE(tgt.presc_addr1, '') <> COALESCE(src.presc_addr1, '') OR
    COALESCE(tgt.presc_addr2, '') <> COALESCE(src.presc_addr2, '') OR
    COALESCE(tgt.presc_city, '') <> COALESCE(src.presc_city, '') OR
    COALESCE(tgt.presc_state, '') <> COALESCE(src.presc_state, '') OR
    COALESCE(tgt.presc_zip, 0.0) <> COALESCE(src.presc_zip, 0.0) OR
    COALESCE(tgt.presc_cred, '') <> COALESCE(src.presc_cred, '') OR
    COALESCE(tgt.presc_typ, '') <> COALESCE(src.presc_typ, '') OR
    COALESCE(tgt.presc_spec1, '') <> COALESCE(src.presc_spec1, '') OR
    COALESCE(tgt.presc_spec2, '') <> COALESCE(src.presc_spec2, '') OR
    COALESCE(tgt.pharm_npi, 0) <> COALESCE(src.pharm_npi, 0) OR
    COALESCE(tgt.pharm_ncpdp_id, 0) <> COALESCE(src.pharm_ncpdp_id, 0) OR
    COALESCE(tgt.pharm_nm, '') <> COALESCE(src.pharm_nm, '') OR
    COALESCE(tgt.pharm_chain_nr, '') <> COALESCE(src.pharm_chain_nr, '') OR
    COALESCE(tgt.pharm_chain_nm, '') <> COALESCE(src.pharm_chain_nm, '') OR
    COALESCE(tgt.pharm_addr1, '') <> COALESCE(src.pharm_addr1, '') OR
    COALESCE(tgt.pharm_addr2, '') <> COALESCE(src.pharm_addr2, '') OR
    COALESCE(tgt.pharm_city, '') <> COALESCE(src.pharm_city, '') OR
    COALESCE(tgt.pharm_state, '') <> COALESCE(src.pharm_state, '') OR
    COALESCE(tgt.pharm_zip, 0) <> COALESCE(src.pharm_zip, 0) OR
    COALESCE(tgt.pat_init_oop, 0.0) <> COALESCE(src.pat_init_oop, 0.0) OR
    COALESCE(tgt.paid_bnft, 0.0) <> COALESCE(src.paid_bnft, 0.0) OR
    COALESCE(tgt.tot_pat_pay_amt, 0.0) <> COALESCE(src.tot_pat_pay_amt, 0.0) OR
    COALESCE(tgt.rej_cd, '') <> COALESCE(src.rej_cd, '') OR
    COALESCE(tgt.rej_desc, '') <> COALESCE(src.rej_desc, '') OR
    COALESCE(tgt.prmry_pyr_bin, '') <> COALESCE(src.prmry_pyr_bin, '') OR
    COALESCE(tgt.txn_stts, '') <> COALESCE(src.txn_stts, '') OR
    COALESCE(tgt.rx_nr, '') <> COALESCE(src.rx_nr, '') OR
    COALESCE(tgt.fill_nr, 0) <> COALESCE(src.fill_nr, 0) OR
    COALESCE(tgt.drug_dose, '') <> COALESCE(src.drug_dose, '') OR
    COALESCE(tgt.sub_comp_cd, 0) <> COALESCE(src.sub_comp_cd, 0) OR
    COALESCE(tgt.daw_cd, 0) <> COALESCE(src.daw_cd, 0) OR
    COALESCE(tgt.coupon_act_use_nr, 0) <> COALESCE(src.coupon_act_use_nr, 0) OR
    COALESCE(tgt.plan_dis_fee, 0.0) <> COALESCE(src.plan_dis_fee, 0.0) OR
    COALESCE(tgt.plan_sales_tax, 0.0) <> COALESCE(src.plan_sales_tax, 0.0) OR
    COALESCE(tgt.prmry_pyr_rej1, '') <> COALESCE(src.prmry_pyr_rej1, '') OR
    COALESCE(tgt.prmry_pyr_rej2, '') <> COALESCE(src.prmry_pyr_rej2, '') OR
    COALESCE(tgt.prmry_pyr_rej3, '') <> COALESCE(src.prmry_pyr_rej3, '') OR
    COALESCE(tgt.clm_prgrm_typ, '') <> COALESCE(src.clm_prgrm_typ, '') OR
    COALESCE(tgt.cov_typ, '') <> COALESCE(src.cov_typ, '') OR
    COALESCE(tgt.ann_cap_max_reach_dt, '') <> COALESCE(src.ann_cap_max_reach_dt, '') OR
    COALESCE(tgt.clm_load_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_load_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.med_clm_sub_id, 0.0) <> COALESCE(src.med_clm_sub_id, 0.0) OR
    COALESCE(tgt.clm_id, '') <> COALESCE(src.clm_id, '') OR
    COALESCE(tgt.clm_sub_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_sub_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.medben_prgrm_id, 0) <> COALESCE(src.medben_prgrm_id, 0) OR
    COALESCE(tgt.med_clm_amt, 0.0) <> COALESCE(src.med_clm_amt, 0.0) OR
    COALESCE(tgt.clm_stts, '') <> COALESCE(src.clm_stts, '') OR
    COALESCE(tgt.svc_dt_from, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt_from, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.svc_dt_to, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt_to, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.insrd_id_nr, '') <> COALESCE(src.insrd_id_nr, '') OR
    COALESCE(tgt.oth_insrd_grp_nr, '') <> COALESCE(src.oth_insrd_grp_nr, '') OR
    COALESCE(tgt.oth_ins_pln_nm, '') <> COALESCE(src.oth_ins_pln_nm, '') OR
    COALESCE(tgt.insrd_grp_nr, '') <> COALESCE(src.insrd_grp_nr, '') OR
    COALESCE(tgt.ins_pln_nm, '') <> COALESCE(src.ins_pln_nm, '') OR
    COALESCE(tgt.oth_hlth_bnft_pln, 0) <> COALESCE(src.oth_hlth_bnft_pln, 0) OR
    COALESCE(tgt.curr_illness_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.curr_illness_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.diag_cd, '') <> COALESCE(src.diag_cd, '') OR
    COALESCE(tgt.svc_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.svc_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.plc_of_svc, '') <> COALESCE(src.plc_of_svc, '') OR
    COALESCE(tgt.ndc, '') <> COALESCE(src.ndc, '') OR
    COALESCE(tgt.diag_ptr, '') <> COALESCE(src.diag_ptr, '') OR
    COALESCE(tgt.chrgs, 0.0) <> COALESCE(src.chrgs, 0.0) OR
    COALESCE(tgt.unts_days, 0) <> COALESCE(src.unts_days, 0) OR
    COALESCE(tgt.prscrbr_npi, 0.0) <> COALESCE(src.prscrbr_npi, 0.0) OR
    COALESCE(tgt.fed_tax_id, 0.0) <> COALESCE(src.fed_tax_id, 0.0) OR
    COALESCE(tgt.svc_fac_loc_info, '') <> COALESCE(src.svc_fac_loc_info, '') OR
    COALESCE(tgt.bill_prov_info, '') <> COALESCE(src.bill_prov_info, '') OR
    COALESCE(tgt.clm_log_stts, '') <> COALESCE(src.clm_log_stts, '') OR
    COALESCE(tgt.clm_log_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.clm_log_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.rej_rsn, '') <> COALESCE(src.rej_rsn, '') OR
    COALESCE(tgt.rej_level, '') <> COALESCE(src.rej_level, '') OR
    COALESCE(tgt.pmt_stts_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) <> COALESCE(src.pmt_stts_dt, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) OR
    COALESCE(tgt.pmt_typ, '') <> COALESCE(src.pmt_typ, '') OR
    COALESCE(tgt.pmt_stts, '') <> COALESCE(src.pmt_stts, '') OR
    COALESCE(tgt.pmt_amt, 0.0) <> COALESCE(src.pmt_amt, 0.0) OR
    COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '')
            );