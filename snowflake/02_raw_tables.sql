-- Synthetic reporting-unit-day regulatory-reporting observations for a fictional
-- Philippine universal bank. Nothing is seeded as a prediction. Randomness is
-- HASH-seeded, so every rebuild is reproducible: per-unit error propensity, drift
-- between controller sign-offs, missed sign-offs, domain-weighted validation
-- rules, false-positive exceptions, remediation-plan effects, and two upstream
-- batch delays that raise exceptions across a whole report domain.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.REPORTING_UNITS AS
WITH units AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS UNIT_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT UNIT_INDEX,
         MOD(ABS(HASH(UNIT_INDEX, 'phbsp-platform')), 1000000) / 1e6 AS U_PLATFORM,
         MOD(ABS(HASH(UNIT_INDEX, 'phbsp-errrate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(UNIT_INDEX, 'phbsp-signoff')), 1000000) / 1e6 AS U_SIGNOFF,
         MOD(ABS(HASH(UNIT_INDEX, 'phbsp-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(UNIT_INDEX, 'phbsp-remediation')), 1000000) / 1e6 AS U_PLAN
  FROM units
)
SELECT 'RU-' || LPAD(UNIT_INDEX::VARCHAR, 4, '0') AS ID,
       'Reporting unit ' || LPAD(UNIT_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every region and domain is present.
       CASE MOD(UNIT_INDEX, 5) WHEN 0 THEN 'Makati City' WHEN 1 THEN 'Cebu City'
            WHEN 2 THEN 'Davao City' WHEN 3 THEN 'Iloilo City' ELSE 'Cagayan de Oro' END AS REGION,
       CASE MOD(UNIT_INDEX, 8) WHEN 0 THEN 'Loans and credit' WHEN 1 THEN 'Loans and credit'
            WHEN 2 THEN 'Loans and credit' WHEN 3 THEN 'Deposits' WHEN 4 THEN 'Deposits'
            WHEN 5 THEN 'Capital adequacy' WHEN 6 THEN 'Liquidity'
            ELSE 'Financial statements' END AS REPORT_DOMAIN,
       UNIT_INDEX,
       IFF(U_PLAN < 0.25, 1, 0) AS ON_REMEDIATION_PLAN,
       ROUND(0.5 + U_PLATFORM * 9.5, 1) AS YEARS_ON_PLATFORM,
       -- Base daily probability of a material reporting error 0.5%-2.9%; ~14% of
       -- units are repeat offenders (x3), and units on a remediation plan x1.5.
       (0.005 + U_RATE * 0.024) * IFF(U_RATE > 0.86, 3, 1) * IFF(U_PLAN < 0.25, 1.5, 1) AS BASE_ERROR_RATE,
       7 * (1 + FLOOR(U_SIGNOFF * 3)) AS SIGNOFF_INTERVAL_DAYS,
       0.58 + U_DISCIPLINE * 0.42 AS SIGNOFF_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.UNIT_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), batch_events AS (
  -- Two upstream batch delays; every unit in the domain raises an exception.
  SELECT * FROM VALUES (31, 'Deposits'), (58, 'Loans and credit') AS o(DAY_INDEX, REPORT_DOMAIN)
), base AS (
  SELECT u.ID AS ENTITY_ID, u.UNIT_INDEX, u.REPORT_DOMAIN, u.YEARS_ON_PLATFORM,
         u.BASE_ERROR_RATE, u.SIGNOFF_INTERVAL_DAYS, u.SIGNOFF_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + u.UNIT_INDEX * 3, u.SIGNOFF_INTERVAL_DAYS) AS DAYS_SINCE_SIGNOFF,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-err')), 1000000) / 1e6 AS U_ERR,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-rule')), 1000000) / 1e6 AS U_RULE,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-checks')), 1000000) / 1e6 AS U_CHECKS,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(u.ID, d.DAY_INDEX, 'phbsp-esc')), 1000000) / 1e6 AS U_ESC,
         b.REPORT_DOMAIN IS NOT NULL AS BATCH_EVENT
  FROM RAW.REPORTING_UNITS u CROSS JOIN days d
  LEFT JOIN batch_events b ON b.DAY_INDEX = d.DAY_INDEX AND b.REPORT_DOMAIN = u.REPORT_DOMAIN
), signoff AS (
  SELECT *,
         IFF(DAYS_SINCE_SIGNOFF = 0, 1, 0) AS SIGNOFF_DUE,
         IFF(DAYS_SINCE_SIGNOFF = 0 AND U_DONE < SIGNOFF_COMPLETION_PROB, 1, 0) AS SIGNOFF_COMPLETED,
         -- Data-quality drift rises between controller sign-offs; weak sign-off discipline carries it over.
         DAYS_SINCE_SIGNOFF / SIGNOFF_INTERVAL_DAYS + (1 - SIGNOFF_COMPLETION_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_ERR < LEAST(0.5, BASE_ERROR_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + YEARS_ON_PLATFORM))) / 4 THEN 2
              WHEN U_ERR < LEAST(0.5, BASE_ERROR_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + YEARS_ON_PLATFORM))) THEN 1
              ELSE 0 END AS ERROR_COUNT
  FROM signoff
), flagged AS (
  SELECT *,
         -- Validation rules catch about 82% of material errors; the rest goes undetected.
         IFF(BATCH_EVENT, 0, IFF(U_DETECT < 0.82, ERROR_COUNT, 0)) AS MATERIAL_ERROR_COUNT,
         -- False positives: higher for high-volume domains.
         IFF(BATCH_EVENT, 1, IFF(U_FP < CASE REPORT_DOMAIN WHEN 'Loans and credit' THEN 0.13
                                       WHEN 'Deposits' THEN 0.12 WHEN 'Capital adequacy' THEN 0.09
                                       WHEN 'Liquidity' THEN 0.10 ELSE 0.08 END, 1, 0)) AS FALSE_POSITIVE_COUNT
  FROM activity
), measured AS (
  SELECT *,
         MATERIAL_ERROR_COUNT + FALSE_POSITIVE_COUNT AS EXCEPTION_COUNT,
         ROUND(CASE REPORT_DOMAIN WHEN 'Loans and credit' THEN 55 WHEN 'Deposits' THEN 110
                    WHEN 'Capital adequacy' THEN 30 WHEN 'Liquidity' THEN 35 ELSE 20 END
               * (0.7 + 0.6 * U_CHECKS) * (1 + 0.4 * ERROR_COUNT)) AS CHECK_COUNT,
         ROUND(CASE REPORT_DOMAIN WHEN 'Loans and credit' THEN 160 ELSE 85 END
               * (0.7 + 0.6 * U_NOISE) * (1 + 0.5 * ERROR_COUNT)) AS RECORD_COUNT,
         CASE REPORT_DOMAIN WHEN 'Loans and credit' THEN 4500000 WHEN 'Deposits' THEN 2000000
              WHEN 'Capital adequacy' THEN 60000000 WHEN 'Liquidity' THEN 25000000 ELSE 8000000 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_BALANCE_PHP
  FROM flagged
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       RECORD_COUNT, CHECK_COUNT,
       ROUND(CHECK_COUNT * AVG_BALANCE_PHP, 2) AS BALANCE_PHP,
       EXCEPTION_COUNT, MATERIAL_ERROR_COUNT,
       IFF(MATERIAL_ERROR_COUNT > 0 AND U_ESC < 0.55, 1, 0) AS ITEMS_ESCALATED,
       CASE WHEN EXCEPTION_COUNT = 0 THEN 'None'
            WHEN BATCH_EVENT THEN 'Upstream batch delay'
            WHEN REPORT_DOMAIN = 'Loans and credit' THEN IFF(U_RULE < 0.4, 'Missing mandatory field', IFF(U_RULE < 0.75, 'GL-to-report variance', 'Counterparty code mismatch'))
            WHEN REPORT_DOMAIN = 'Deposits' THEN IFF(U_RULE < 0.45, 'Stale reference data', IFF(U_RULE < 0.8, 'GL-to-report variance', 'Duplicate record'))
            WHEN REPORT_DOMAIN = 'Capital adequacy' THEN IFF(U_RULE < 0.5, 'Risk-weight mapping error', 'GL-to-report variance')
            WHEN REPORT_DOMAIN = 'Liquidity' THEN IFF(U_RULE < 0.45, 'Maturity bucket mismatch', IFF(U_RULE < 0.8, 'Stale reference data', 'Duplicate record'))
            ELSE IFF(U_RULE < 0.5, 'Cross-report inconsistency', IFF(U_RULE < 0.75, 'GL-to-report variance', 'Missing mandatory field')) END AS VALIDATION_RULE,
       SIGNOFF_DUE, SIGNOFF_COMPLETED,
       ROUND(3 + 7 * DRIFT + 8 * ERROR_COUNT + U_NOISE * 3, 2) AS LATE_FEED_PCT,
       ROUND(0.4 + 1.6 * DRIFT + 3.5 * ERROR_COUNT + U_NOISE * 1.3, 2) AS RECON_VARIANCE_RATE,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Source-system feed mapping coverage per reporting unit (lineage snapshot).
CREATE TABLE RAW.SOURCE_FEEDS AS
SELECT ID AS ENTITY_ID,
       CASE REPORT_DOMAIN WHEN 'Loans and credit' THEN 'Loan origination system'
                          WHEN 'Deposits' THEN 'Core deposit system'
                          WHEN 'Capital adequacy' THEN 'Risk-weighted asset engine'
                          WHEN 'Liquidity' THEN 'Treasury and ALM system'
                          ELSE 'General ledger' END AS SOURCE_SYSTEM,
       1 + MOD(ABS(HASH(ID, 'phbsp-req')), 4) AS REQUIRED_FEEDS,
       MOD(ABS(HASH(ID, 'phbsp-mapped')), 5) AS MAPPED_FEEDS,
       IFF(MOD(ABS(HASH(ID, 'phbsp-mapped')), 5) < 1 + MOD(ABS(HASH(ID, 'phbsp-req')), 4),
           MOD(ABS(HASH(ID, 'phbsp-pending')), 3), 0) AS PENDING_FEEDS,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.REPORTING_UNITS;
