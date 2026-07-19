SELECT *
FROM `physionet-data.mimiciv_3_1_hosp.admissions`
LIMIT 10;

SELECT *
FROM `physionet-data.mimiciv_3_1_icu.icustays`
LIMIT 10;

SELECT table_name
FROM `physionet-data.mimiciv_3_1_derived.INFORMATION_SCHEMA.TABLES`;

SELECT *
FROM physionet-data.mimiciv_3_1_derived.first_day_vitalsign
LIMIT 5;

SELECT *
FROM physionet-data.mimiciv_3_1_derived.first_day_lab
LIMIT 5;

SELECT 
  icu.subject_id,
  icu.stay_id,
  icu.hadm_id, 
  icu.los,
  icu.first_careunit, 
  adm.hospital_expire_flag,
  adm.admission_type,
  age.age
FROM physionet-data.mimiciv_3_1_icu.icustays icu
LEFT JOIN physionet-data.mimiciv_3_1_hosp.admissions adm
  ON icu.hadm_id = adm.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.age age
  ON icu.hadm_id = age.hadm_id
LIMIT 100;

SELECT 
  icu.subject_id,
  icu.stay_id,
  icu.los,
  icu.first_careunit,
  adm.hospital_expire_flag,
  adm.admission_type,
  adm.race,
  age.age,
  -- vitals
  v.heart_rate_min, v.heart_rate_max, v.heart_rate_mean,
  v.sbp_min, v.sbp_max, v.sbp_mean,
  v.dbp_min, v.dbp_max, v.dbp_mean,
  v.mbp_min, v.mbp_max, v.mbp_mean,
  v.resp_rate_min, v.resp_rate_max, v.resp_rate_mean,
  v.temperature_min, v.temperature_max, v.temperature_mean,
  v.spo2_min, v.spo2_max, v.spo2_mean,
  v.glucose_min, v.glucose_max, v.glucose_mean,
  -- labs
  l.hematocrit_min, l.hematocrit_max,
  l.hemoglobin_min, l.hemoglobin_max,
  l.platelets_min, l.platelets_max,
  l.wbc_min, l.wbc_max,
  l.creatinine_min, l.creatinine_max,
  l.bun_min, l.bun_max,
  l.sodium_min, l.sodium_max,
  l.potassium_min, l.potassium_max,
  l.bicarbonate_min, l.bicarbonate_max,
  l.inr_min, l.inr_max,
  l.bilirubin_total_min, l.bilirubin_total_max

FROM physionet-data.mimiciv_3_1_icu.icustays icu
LEFT JOIN physionet-data.mimiciv_3_1_hosp.admissions adm
  ON icu.hadm_id = adm.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.age age
  ON icu.hadm_id = age.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_vitalsign v
  ON icu.stay_id = v.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_lab l
  ON icu.stay_id = l.stay_id;

SELECT 
  icu.subject_id,
  icu.stay_id,
  icu.los,
  icu.first_careunit,
  adm.hospital_expire_flag,
  adm.admission_type,
  adm.race,
  age.age,
  vent_day1.ventilated_day1,
  v.* EXCEPT (subject_id, stay_id),
  l.* EXCEPT (subject_id, stay_id),
  gcs.* EXCEPT (subject_id, stay_id),
  sofa.* EXCEPT (subject_id, stay_id),
  uo.* EXCEPT (subject_id, stay_id),
  w.* EXCEPT (subject_id, stay_id),
  sep.sepsis3

FROM physionet-data.mimiciv_3_1_icu.icustays icu
LEFT JOIN physionet-data.mimiciv_3_1_hosp.admissions adm
  ON icu.hadm_id = adm.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.age age
  ON icu.hadm_id = age.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_vitalsign v
  ON icu.stay_id = v.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_lab l
  ON icu.stay_id = l.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_gcs gcs
  ON icu.stay_id = gcs.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_sofa sofa
  ON icu.stay_id = sofa.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_urine_output uo
  ON icu.stay_id = uo.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.sepsis3 sep
  ON icu.stay_id = sep.stay_id
LEFT JOIN (
  SELECT 
    icu2.stay_id,
    MAX(CASE WHEN v2.ventilation_status IS NOT NULL THEN 1 ELSE 0 END) as ventilated_day1
  FROM physionet-data.mimiciv_3_1_icu.icustays icu2
  LEFT JOIN physionet-data.mimiciv_3_1_derived.ventilation v2
    ON icu2.stay_id = v2.stay_id
    AND v2.starttime <= DATETIME_ADD(icu2.intime, INTERVAL 24 HOUR)
    AND v2.endtime >= icu2.intime
  GROUP BY icu2.stay_id
) vent_day1
  ON icu.stay_id = vent_day1.stay_id
LEFT JOIN physionet-data.mimiciv_3_1_derived.first_day_weight w
  ON icu.stay_id = w.stay_id;

SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 0;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 9000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 18000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 27000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 36000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 45000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 54000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 63000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 72000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 81000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.mortality_features` LIMIT 9000 OFFSET 90000;