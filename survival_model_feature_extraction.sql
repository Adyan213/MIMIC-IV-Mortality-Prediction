SELECT 
icu.subject_id, 
icu.hadm_id, 
icu.stay_id, 
icu.intime,
icu.outtime,
adm.admittime,
adm.dischtime,
adm.deathtime,
adm.hospital_expire_flag,
patient.dod

FROM physionet-data.mimiciv_3_1_icu.icustays icu
LEFT JOIN physionet-data.mimiciv_3_1_hosp.admissions adm
ON icu.hadm_id=adm.hadm_id
LEFT JOIN physionet-data.mimiciv_3_1_hosp.patients patient
ON icu.subject_id=patient.subject_id
LIMIT 100;

-- check for null in, out and discharge times --

SELECT
  COUNTIF(icu.intime IS NULL) AS null_intime,
  COUNTIF(icu.outtime IS NULL) AS null_outtime,
  COUNTIF(adm.dischtime IS NULL) AS null_dischtime
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id;

SELECT 
icu.stay_id, icu.intime, icu.outtime, icu.los,
adm.dischtime, adm.deathtime, adm.hospital_expire_flag
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id
WHERE icu.outtime is NULL;

-- Deaths without death times --
SELECT 
COUNTIF(adm.deathtime is NULL) AS null_deathtime 
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id
  WHERE adm.hospital_expire_flag = 1;

-- Impossible orderings --
SELECT 
COUNTIF(adm.dischtime < icu.intime) AS impossible_ordering1,
COUNTIF(adm.deathtime < icu.intime) AS impossible_ordering2
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id;

-- checking deathtime > dischtime --
SELECT 
COUNTIF(adm.deathtime > adm.dischtime) AS check4,
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id;

-- Checking if the difference b/w death and discharge is high --
SELECT 
adm.deathtime, adm.dischtime,
FROM `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id
  WHERE adm.deathtime > adm.dischtime
  ORDER BY TIMESTAMP_DIFF(adm.deathtime, adm.dischtime, MINUTE) DESC;

-- Stays that end in 24 hours --
WITH stays AS (
  SELECT
    icu.stay_id,
    icu.intime,
    CASE WHEN adm.hospital_expire_flag = 1
         THEN COALESCE(adm.deathtime, adm.dischtime)
         ELSE adm.dischtime
    END AS end_time
  FROM  `physionet-data.mimiciv_3_1_icu.icustays` icu
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
  ON icu.hadm_id = adm.hadm_id
  WHERE adm.hospital_expire_flag = 1
)
SELECT
  COUNT(*) AS total,
  COUNTIF(DATETIME_DIFF(end_time, intime, MINUTE) < 1440) AS ends_within_24h
FROM stays;


--Multi stay admissions--
SELECT COUNT(*) AS multi_stay_admissions
FROM (
  SELECT hadm_id
  FROM `physionet-data.mimiciv_3_1_icu.icustays`
  GROUP BY hadm_id
  HAVING COUNT(*) > 1
);

CREATE OR REPLACE TABLE `mimic-iv-analysis-213.mimic_iv_export.survival_cohort` AS
WITH base AS (
  SELECT 
    icu.subject_id, 
    icu.hadm_id, 
    icu.stay_id,
    icu.intime,
    adm.hospital_expire_flag,
    CASE WHEN adm.hospital_expire_flag=1
        THEN COALESCE(adm.deathtime, adm.dischtime)
        ELSE adm.dischtime
    END AS end_time,
    ROW_NUMBER() OVER (PARTITION BY icu.hadm_id ORDER BY icu.intime) AS stay_rank
    FROM  `physionet-data.mimiciv_3_1_icu.icustays` icu
    LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm
    ON icu.hadm_id = adm.hadm_id
),

first_stay AS (
  SELECT *,
  DATETIME_DIFF(end_time, DATETIME_ADD(intime, INTERVAL 24 HOUR), MINUTE)/1440.0 AS raw_days
  FROM base
  WHERE stay_rank=1
)

SELECT
subject_id,
hadm_id,
stay_id,
LEAST(raw_days, 30) AS duration_days,
CASE WHEN raw_days>30 THEN 0 ELSE hospital_expire_flag END AS event
FROM first_stay
WHERE raw_days>0;

SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT hadm_id) AS distinct_adm,
  COUNT(DISTINCT subject_id) AS distinct_subj,
  SUM(event) AS total_deaths,
  MIN(duration_days) AS min_dur,
  MAX(duration_days) AS max_dur
FROM `mimic-iv-analysis-213.mimic_iv_export.survival_cohort`;


--mortality features--
CREATE OR REPLACE TABLE `mimic-iv-analysis-213.mimic_iv_export.mortality_features` AS
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
  v.* EXCEPT (subject_id, stay_id, glucose_min, glucose_max),
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

-- Final Table --
CREATE OR REPLACE TABLE mimic-iv-analysis-213.mimic_iv_export.survival_model_data AS
SELECT 
c.*,
f.* EXCEPT(subject_id, stay_id, los, hospital_expire_flag, hadm_id)
FROM `mimic-iv-analysis-213.mimic_iv_export.survival_cohort` c
LEFT JOIN `mimic-iv-analysis-213.mimic_iv_export.mortality_features` f
on c.stay_id=f.stay_id;

SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 0;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 9000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 18000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 27000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 36000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 45000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 54000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 63000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 72000;
SELECT * FROM `mimic-iv-analysis-213.mimic_iv_export.survival_model_data` ORDER BY stay_id LIMIT 9000 OFFSET 81000;