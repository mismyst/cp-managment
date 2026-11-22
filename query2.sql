

--- SQL Statements to be Executed ---

--- Control Table Insert ---
MERGE INTO edb_conform_bu_c360_dev.etl_control.control_table AS t
    USING (
    SELECT
        '205221172454520'     AS job_id,
        'lnd_care_program_product_dim'     AS tbl_nm,
        'SCD2_lnd_care_program_product_dim_Pipeline' as ppln_nm,
        'lnd_lsc_uat'    AS schm_nm,
        'LSC' AS src_system,
        'Started'  AS sts,
        NULL AS jb_end_ts,
        current_timestamp() AS updt_at,
        current_timestamp() AS lst_run_ts,
        ""   AS merge_qery,
        ""  AS insert_query,
        ""         AS ddl_query
    ) s
    ON  t.job_id     = s.job_id
    AND t.tbl_nm     = s.tbl_nm
    AND t.schm_nm    = s.schm_nm
    AND t.src_system = s.src_system

    WHEN MATCHED AND t.sts = 'Started' THEN UPDATE SET
    t.sts          = s.sts,
    t.jb_end_ts   = s.jb_end_ts,
    t.updt_at      = s.updt_at,
    t.merge_qery  = s.merge_qery,
    t.insert_query = s.insert_query,
    t.ddl_query    = s.ddl_query
    
WHEN NOT MATCHED THEN INSERT (
  job_id, tbl_nm, ppln_nm,schm_nm, src_system, sts, lst_run_ts,jb_end_ts, updt_at, merge_qery, insert_query, ddl_query
) VALUES (
  s.job_id, s.tbl_nm, s.ppln_nm,s.schm_nm, s.src_system, s.sts, s.lst_run_ts, s.jb_end_ts,s.updt_at, s.merge_qery, s.insert_query, s.ddl_query)

--- SCD2 MERGE ---

MERGE INTO edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt USING (select * from (( SELECT src.ssot__Id__c AS id, src.ssot__CareProgramId__c AS cr_prgrm_id, src.ssot__ProductId__c AS prdct_id, src.ssot__Name__c AS nm, src.Created_By_ID__c AS src_crtd_by_id, CAST(DATE_FORMAT(src.Created_Date__c,'yyyy-MM-dd') AS DATE) AS src_crtd_dt, src.Last_Modified_By_ID__c AS src_lst_mdfd_by_id, CAST(DATE_FORMAT(src.Last_Modified_Date__c,'yyyy-MM-dd') AS DATE) AS src_lst_mdfd_dt, DATE_FORMAT(src.Created_Date__c,'yyyy-MM') AS src_crtd_yr_mnth, 'LSC' AS etl_src_id, CAST(NULL AS varchar(100)) AS etl_src_rec_id, CAST(NULL AS date) AS src_dt, CURRENT_DATE() AS crtd_dt, 'SYSTEM' AS crtd_by, CURRENT_DATE() AS updt_dt, 'SYSTEM' AS updt_by, CURRENT_TIMESTAMP() AS etl_dt, CURRENT_DATE() AS eff_strt_dt, DATE '9999-12-31' AS eff_end_dt, CURRENT_TIMESTAMP() AS lst_updt_ts, TRUE AS is_actv, 'I' AS opn_flg, Null AS ext_fld_1, 141696125945998 as etl_job_id, row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY src.Last_Modified_Date__c DESC) AS RN FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src WHERE src.Last_Modified_Date__c >= (SELECT COALESCE(MAX(lst_run_ts) - INTERVAL 60 MINUTES, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') ) AS src) where RN = 1) as src ON tgt.id <=> src.id AND tgt.is_actv = TRUE WHEN MATCHED AND ( COALESCE(tgt.id, '') <> COALESCE(src.id, '') OR COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, '') OR COALESCE(tgt.nm, '') <> COALESCE(src.nm, '') OR COALESCE(tgt.src_crtd_by_id, '') <> COALESCE(src.src_crtd_by_id, '') OR COALESCE(tgt.src_crtd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_crtd_dt, CAST('1900-01-01' AS DATE)) OR COALESCE(tgt.src_lst_mdfd_by_id, '') <> COALESCE(src.src_lst_mdfd_by_id, '') OR COALESCE(tgt.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) OR COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '') ) THEN UPDATE SET eff_end_dt = CURRENT_DATE(), is_actv = FALSE, lst_updt_ts = CURRENT_TIMESTAMP(), updt_dt = CURRENT_DATE(), updt_by = 'SYSTEM', etl_job_id = '141696125945998' WHEN NOT MATCHED BY TARGET THEN INSERT ( id, cr_prgrm_id, prdct_id, nm, src_crtd_by_id, src_crtd_dt, src_lst_mdfd_by_id, src_lst_mdfd_dt, src_crtd_yr_mnth, etl_src_id, etl_src_rec_id, src_dt, crtd_dt, crtd_by, updt_dt, updt_by, etl_dt, eff_strt_dt, eff_end_dt, lst_updt_ts, is_actv, opn_flg, ext_fld_1, etl_job_id ) VALUES ( src.id, src.cr_prgrm_id, src.prdct_id, src.nm, src.src_crtd_by_id, src.src_crtd_dt, src.src_lst_mdfd_by_id, src.src_lst_mdfd_dt, src.src_crtd_yr_mnth, src.etl_src_id, src.etl_src_rec_id, src.src_dt, src.crtd_dt, src.crtd_by, src.updt_dt, src.updt_by, src.etl_dt, src.eff_strt_dt, src.eff_end_dt, src.lst_updt_ts, src.is_actv, src.opn_flg, src.ext_fld_1, src.etl_job_id );

INSERT QUERY : 
INSERT INTO edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim ( id, cr_prgrm_id, prdct_id, nm, src_crtd_by_id, src_crtd_dt, src_lst_mdfd_by_id, src_lst_mdfd_dt, src_crtd_yr_mnth, etl_src_id, etl_src_rec_id, src_dt, crtd_dt, crtd_by, updt_dt, updt_by, etl_dt, eff_strt_dt, eff_end_dt, lst_updt_ts, is_actv, opn_flg, ext_fld_1, etl_job_id ) SELECT src.id, src.cr_prgrm_id, src.prdct_id, src.nm, src.src_crtd_by_id, src.src_crtd_dt, src.src_lst_mdfd_by_id, src.src_lst_mdfd_dt, src.src_crtd_yr_mnth, src.etl_src_id, src.etl_src_rec_id, src.src_dt, src.crtd_dt, src.crtd_by, src.updt_dt, src.updt_by, src.etl_dt, src.eff_strt_dt, src.eff_end_dt, src.lst_updt_ts, src.is_actv, src.opn_flg, src.ext_fld_1, src.etl_job_id FROM (Select src.ssot__Id__c AS id, src.ssot__CareProgramId__c AS cr_prgrm_id, src.ssot__ProductId__c AS prdct_id, src.ssot__Name__c AS nm, src.Created_By_ID__c AS src_crtd_by_id, CAST(DATE_FORMAT(src.Created_Date__c,'yyyy-MM-dd') AS DATE) AS src_crtd_dt, src.Last_Modified_By_ID__c AS src_lst_mdfd_by_id, CAST(DATE_FORMAT(src.Last_Modified_Date__c,'yyyy-MM-dd') AS DATE) AS src_lst_mdfd_dt, DATE_FORMAT(src.Created_Date__c,'yyyy-MM') AS src_crtd_yr_mnth, 'LSC' AS etl_src_id, CAST(NULL AS varchar(100)) AS etl_src_rec_id, CAST(NULL AS date) AS src_dt, CURRENT_DATE() AS crtd_dt, 'SYSTEM' AS crtd_by, CURRENT_DATE() AS updt_dt, 'SYSTEM' AS updt_by, CURRENT_TIMESTAMP() AS etl_dt, CURRENT_DATE() AS eff_strt_dt, DATE '9999-12-31' AS eff_end_dt, CURRENT_TIMESTAMP() AS lst_updt_ts, TRUE AS is_actv, 'U' AS opn_flg, Null AS ext_fld_1, 141696125945998 as etl_job_id, row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY src.Last_Modified_Date__c DESC) AS RN FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src ) AS src LEFT JOIN edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt ON tgt.id <=> src.id WHERE tgt.lst_updt_ts between (SELECT COALESCE(MAX(lst_run_ts), CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') and CURRENT_TIMESTAMP() AND RN = 1 AND tgt.is_actv = FALSE and tgt.etl_job_id = '141696125945998' AND ( COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, '') OR COALESCE(tgt.nm, '') <> COALESCE(src.nm, '') OR COALESCE(tgt.src_crtd_by_id, '') <> COALESCE(src.src_crtd_by_id, '') OR COALESCE(tgt.src_crtd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_crtd_dt, CAST('1900-01-01' AS DATE)) OR COALESCE(tgt.src_lst_mdfd_by_id, '') <> COALESCE(src.src_lst_mdfd_by_id, '') OR COALESCE(tgt.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) OR COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '') );


MERGE INTO edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt
USING (select * from ((
        SELECT  
       *
        """LSC""" AS etl_src_id,
        CAST(NULL AS varchar(100)) AS etl_src_rec_id,
        CAST(NULL AS date) AS src_dt,
        CURRENT_DATE() AS crtd_dt,
        """SYSTEM""" AS crtd_by,
        CURRENT_DATE() AS updt_dt,
        """SYSTEM""" AS updt_by,
        CURRENT_TIMESTAMP() AS etl_dt,
        CURRENT_DATE() AS eff_strt_dt,
        DATE '9999-12-31' AS eff_end_dt,
        CURRENT_TIMESTAMP() AS lst_updt_ts,
        TRUE AS is_actv,
        'I' AS opn_flg,
        Null AS ext_fld_1,
        205221172454520 as etl_job_id,
         row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY  src.Last_Modified_Date__c DESC) AS RN 
        FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src
 WHERE  src.Last_Modified_Date__c >= (SELECT COALESCE(MAX(lst_run_ts)  - INTERVAL 60 MINUTES, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') 
        ) AS src) where  RN = 1) as src 
ON
    tgt.id <=> src.id AND
    tgt.is_actv = TRUE
WHEN MATCHED AND (
    COALESCE(tgt.id, '') <> COALESCE(src.id, '') OR
    COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR
    COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, ''

... [*** WARNING: max output size exceeded, skipping output. ***] ...

 AS etl_src_rec_id,
    CAST(NULL AS date) AS src_dt,
    CURRENT_DATE() AS crtd_dt,
    """SYSTEM""" AS crtd_by,
    CURRENT_DATE() AS updt_dt,
    """SYSTEM""" AS updt_by,
    CURRENT_TIMESTAMP() AS etl_dt,
    CURRENT_DATE() AS eff_strt_dt,
    DATE '9999-12-31' AS eff_end_dt,
    CURRENT_TIMESTAMP() AS lst_updt_ts,
    TRUE AS is_actv,
    'U' AS opn_flg,
    Null AS ext_fld_1,
    205221172454520 as etl_job_id,
     row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY  src.Last_Modified_Date__c DESC) AS RN 
        FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src
         ) AS src
        LEFT JOIN edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt
        ON
            tgt.id <=> src.id
        WHERE
            tgt.lst_updt_ts between (SELECT COALESCE(MAX(lst_run_ts), CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') and CURRENT_TIMESTAMP() 
            AND RN = 1
            AND tgt.is_actv = FALSE
            and tgt.etl_job_id = '205221172454520'
            AND (
                COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR
    COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, '') OR
    COALESCE(tgt.nm, '') <> COALESCE(src.nm, '') OR
    COALESCE(tgt.src_crtd_by_id, '') <> COALESCE(src.src_crtd_by_id, '') OR
    COALESCE(tgt.src_crtd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_crtd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_lst_mdfd_by_id, '') <> COALESCE(src.src_lst_mdfd_by_id, '') OR
    COALESCE(tgt.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '')
            );

--- Control Table Update (Success) ---
MERGE INTO edb_conform_bu_c360_dev.etl_control.control_table AS t
    USING (
    SELECT
        '205221172454520'     AS job_id,
        'lnd_care_program_product_dim'     AS tbl_nm,
        'lnd_lsc_uat'    AS schm_nm,
        'LSC' AS src_system,
        'Success'  AS sts,
        current_timestamp() AS jb_end_ts,
        current_timestamp() AS updt_at,
        "MERGE INTO edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt
USING (select * from ((
        SELECT  
            src.ssot__Id__c AS id,
        src.ssot__CareProgramId__c AS cr_prgrm_id,
        src.ssot__ProductId__c AS prdct_id,
        src.ssot__Name__c AS nm,
        src.Created_By_ID__c AS src_crtd_by_id,
        CAST(DATE_FORMAT(src.Created_Date__c,'yyyy-MM-dd') AS DATE) AS src_crtd_dt,
        src.Last_Modified_By_ID__c AS src_lst_mdfd_by_id,
        CAST(DATE_FORMAT(src.Last_Modified_Date__c,'yyyy-MM-dd') AS DATE) AS src_lst_mdfd_dt,
        DATE_FORMAT(src.Created_Date__c,'yyyy-MM') AS src_crtd_yr_mnth,
        'LSC' AS etl_src_id,
        CAST(NULL AS varchar(100)) AS etl_src_rec_id,
        CAST(NULL AS date) AS src_dt,
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
        205221172454520 as etl_job_id,
         row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY  src.Last_Modified_Date__c DESC) AS RN 
        FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src
 WHERE  src.Last_Modified_Date__c >= (SELECT COALESCE(MAX(lst_run_ts)  - INTERVAL 60 MINUTES, CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') 
        ) AS src) where  RN = 1) as src 
ON
    tgt.id <=> src.id AND
    tgt.is_actv = TRUE
WHEN MATCHED AND (
    COALESCE(tgt.id, '') <> COALESCE(src.id, '') OR
    COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR
    COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, '') OR
    COALESCE(tgt.nm, '') <> COALESCE(src.nm, '') OR
    COALESCE(tgt.src_crtd_by_id, '') <> COALESCE(src.src_crtd_by_id, '') OR
    COALESCE(tgt.src_crtd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_crtd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_lst_mdfd_by_id, '') <> COALESCE(src.src_lst_mdfd_by_id, '') OR
    COALESCE(tgt.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '')
) THEN
    UPDATE SET
        eff_end_dt = CURRENT_DATE(),
        is_actv = FALSE,
        lst_updt_ts = CURRENT_TIMESTAMP(),
        updt_dt = CURRENT_DATE(),
        updt_by = 'SYSTEM',
        etl_job_id = '205221172454520'
WHEN NOT MATCHED BY TARGET THEN
    INSERT (
        id,
        cr_prgrm_id,
        prdct_id,
        nm,
        src_crtd_by_id,
        src_crtd_dt,
        src_lst_mdfd_by_id,
        src_lst_mdfd_dt,
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
        src.id,
        src.cr_prgrm_id,
        src.prdct_id,
        src.nm,
        src.src_crtd_by_id,
        src.src_crtd_dt,
        src.src_lst_mdfd_by_id,
        src.src_lst_mdfd_dt,
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
    );"   AS merge_qery ,
        "INSERT INTO edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim (
            id, cr_prgrm_id, prdct_id, nm, src_crtd_by_id, src_crtd_dt, src_lst_mdfd_by_id, src_lst_mdfd_dt, src_crtd_yr_mnth, etl_src_id, etl_src_rec_id, src_dt, crtd_dt, crtd_by, updt_dt, updt_by, etl_dt, eff_strt_dt, eff_end_dt, lst_updt_ts, is_actv, opn_flg, ext_fld_1, etl_job_id
        )
        SELECT src.id, src.cr_prgrm_id, src.prdct_id, src.nm, src.src_crtd_by_id, src.src_crtd_dt, src.src_lst_mdfd_by_id, src.src_lst_mdfd_dt, src.src_crtd_yr_mnth, src.etl_src_id, src.etl_src_rec_id, src.src_dt, src.crtd_dt, src.crtd_by, src.updt_dt, src.updt_by, src.etl_dt, src.eff_strt_dt, src.eff_end_dt, src.lst_updt_ts, src.is_actv, src.opn_flg, src.ext_fld_1, src.etl_job_id FROM (Select  
            src.ssot__Id__c AS id,
    src.ssot__CareProgramId__c AS cr_prgrm_id,
    src.ssot__ProductId__c AS prdct_id,
    src.ssot__Name__c AS nm,
    src.Created_By_ID__c AS src_crtd_by_id,
    CAST(DATE_FORMAT(src.Created_Date__c,'yyyy-MM-dd') AS DATE) AS src_crtd_dt,
    src.Last_Modified_By_ID__c AS src_lst_mdfd_by_id,
    CAST(DATE_FORMAT(src.Last_Modified_Date__c,'yyyy-MM-dd') AS DATE) AS src_lst_mdfd_dt,
    DATE_FORMAT(src.Created_Date__c,'yyyy-MM') AS src_crtd_yr_mnth,
    'LSC' AS etl_src_id,
    CAST(NULL AS varchar(100)) AS etl_src_rec_id,
    CAST(NULL AS date) AS src_dt,
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
    205221172454520 as etl_job_id,
     row_number() OVER( PARTITION BY src.ssot__Id__c ORDER BY  src.Last_Modified_Date__c DESC) AS RN 
        FROM bu_sfdc_full1_qa.default.ssot__careprogramproduct__dlm AS src
         ) AS src
        LEFT JOIN edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim AS tgt
        ON
            tgt.id <=> src.id
        WHERE
            tgt.lst_updt_ts between (SELECT COALESCE(MAX(lst_run_ts), CAST('1900-01-01 00:00:00' AS TIMESTAMP)) FROM edb_conform_bu_c360_dev.etl_control.control_table WHERE sts = 'Success' AND tbl_nm = 'lnd_care_program_product_dim' AND schm_nm = 'lnd_lsc_uat' and src_system = 'LSC') and CURRENT_TIMESTAMP() 
            AND RN = 1
            AND tgt.is_actv = FALSE
            and tgt.etl_job_id = '205221172454520'
            AND (
                COALESCE(tgt.cr_prgrm_id, '') <> COALESCE(src.cr_prgrm_id, '') OR
    COALESCE(tgt.prdct_id, '') <> COALESCE(src.prdct_id, '') OR
    COALESCE(tgt.nm, '') <> COALESCE(src.nm, '') OR
    COALESCE(tgt.src_crtd_by_id, '') <> COALESCE(src.src_crtd_by_id, '') OR
    COALESCE(tgt.src_crtd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_crtd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_lst_mdfd_by_id, '') <> COALESCE(src.src_lst_mdfd_by_id, '') OR
    COALESCE(tgt.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) <> COALESCE(src.src_lst_mdfd_dt, CAST('1900-01-01' AS DATE)) OR
    COALESCE(tgt.src_crtd_yr_mnth, '') <> COALESCE(src.src_crtd_yr_mnth, '')
            );"  AS insert_query,
        "CREATE OR REPLACE TABLE  edb_refined_bu_c360_dev .lnd_lsc_uat.lnd_care_program_product_dim (
 cr_prgrm_prdct_ky bigint NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1) COMMENT 'care program product key' ,
  id varchar(40)  NOT NULL COMMENT 'ssot  Id' ,
  cr_prgrm_id varchar(40)  COMMENT 'ssotareProgramId' ,
  prdct_id varchar(18)  COMMENT 'ssot  ProductId' ,
  nm varchar(255)  COMMENT 'ssot  Name' ,
  src_crtd_by_id varchar(18)  COMMENT 'Created By ID' ,
  src_crtd_dt date  COMMENT 'Created Date' ,
  src_lst_mdfd_by_id varchar(18)  COMMENT 'Last Modified By ID' ,
  src_lst_mdfd_dt date  COMMENT 'Last Modified Date' ,
  src_crtd_yr_mnth varchar(20)  COMMENT 'src crtd dt' ,
  etl_job_id varchar(100)  COMMENT 'ETL Job Identifier' ,
  etl_src_id varchar(100)  COMMENT 'ETL Source Identifier' ,
  etl_src_rec_id varchar(100)  COMMENT 'ETL Source Record Identifier' ,
  src_dt date  COMMENT 'Source Date' ,
  crtd_dt date  COMMENT 'Created Date' ,
  crtd_by varchar(100)  COMMENT 'Created By' ,
  updt_dt date  COMMENT 'Updated Date' ,
  updt_by varchar(100)  COMMENT 'Updated By' ,
  etl_dt timestamp  COMMENT 'ETL Date' ,
  eff_strt_dt date  COMMENT 'Effective_Start_Date' ,
  eff_end_dt date  COMMENT 'Effective_End_Date' ,
  lst_updt_ts timestamp  COMMENT 'Last Updated Timestamp' ,
  is_actv boolean  COMMENT 'Active Flag' ,
  opn_flg varchar(5)  COMMENT 'Operation Flag' ,
  ext_fld_1 varchar(100)  COMMENT 'Extension Field 1' ,
 CONSTRAINT `lnd_care_program_product_dim_pk` PRIMARY KEY (`cr_prgrm_prdct_ky`))  PARTITIONED BY (src_crtd_yr_mnth);"           AS ddl_query
    ) s
    ON  t.job_id     = s.job_id
    AND t.tbl_nm     = s.tbl_nm
    AND t.schm_nm    = s.schm_nm
    AND t.src_system = s.src_system

    WHEN MATCHED AND t.sts = 'Started' THEN UPDATE SET
    t.sts          = s.sts,
    t.jb_end_ts   = s.jb_end_ts,
    t.updt_at      = s.updt_at,
    t.merge_qery  = s.merge_qery,
    t.insert_query = s.insert_query,
    t.ddl_query    = s.ddl_query