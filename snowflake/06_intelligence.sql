-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-event alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_EVENTS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic regulatory-reporting knowledge base (clearly synthetic SOPs) ----------
-- These are internal procedures of a fictional bank, not regulatory text or BSP guidance.
CREATE OR REPLACE TABLE SEARCH.REPORTING_DOCS AS
WITH rules AS (
  SELECT DISTINCT r.VALIDATION_RULE, u.REPORT_DOMAIN
  FROM RAW.UNIT_DAILY r JOIN RAW.REPORTING_UNITS u ON u.ID = r.ENTITY_ID
  WHERE r.MATERIAL_ERROR_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY REPORT_DOMAIN, VALIDATION_RULE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  REPORT_DOMAIN,
  VALIDATION_RULE,
  REPORT_DOMAIN || ' returns - ' || VALIDATION_RULE || ' exception handling' AS TITLE,
  'Synthetic demo SOP for a fictional bank. Report domain: ' || REPORT_DOMAIN || '. Validation rule: ' || VALIDATION_RULE || '. '
  || 'Step 1: open a data-quality ticket, link the exception and freeze the affected source extract and report working file. '
  || 'Step 2: ' || CASE
       WHEN VALIDATION_RULE = 'Missing mandatory field' THEN 'list the records with blank mandatory fields, trace each to its source-system record and ask the data owner to populate it at source rather than in the report file.'
       WHEN VALIDATION_RULE = 'GL-to-report variance' THEN 'reconcile the report line to the general ledger trial balance for the same cut-off date and explain or correct every variance above the internal tolerance.'
       WHEN VALIDATION_RULE = 'Counterparty code mismatch' THEN 'compare counterparty and borrower codes with the customer master, correct mapping-table entries and rerun the extract.'
       WHEN VALIDATION_RULE = 'Stale reference data' THEN 'confirm the reference table version (branch, product and rate codes) used by the extract and reload the current version before rerunning.'
       WHEN VALIDATION_RULE = 'Duplicate record' THEN 'identify duplicated keys, check whether the source batch was loaded twice, and remove duplicates through the controlled reload process.'
       WHEN VALIDATION_RULE = 'Risk-weight mapping error' THEN 'check the product-to-risk-weight mapping table against the bank''s approved internal methodology and recompute the affected exposures.'
       WHEN VALIDATION_RULE = 'Maturity bucket mismatch' THEN 'recompute the residual maturity of each flagged position from the contract dates and reassign it to the correct internal maturity bucket.'
       WHEN VALIDATION_RULE = 'Cross-report inconsistency' THEN 'compare the shared totals between the related internal returns and correct the return that departs from the reconciled general ledger figure.'
       ELSE 'review the flagged records against the source system and escalate if unexplained.'
     END
  || ' Step 3: if late source feeds exceed 20% of the day''s feeds or the reconciliation variance rate exceeds 6 per 100 records after review, keep the ticket open and notify the reporting controller. '
  || 'Step 4: record the resolution; if a material error is confirmed, escalate the item to the head of regulatory reporting for a decision on resubmission and disclosure under the bank''s internal policy.' AS CONTENT
FROM rules;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.REPORTING_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES REPORT_DOMAIN, VALIDATION_RULE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, REPORT_DOMAIN, VALIDATION_RULE, CONTENT FROM SEARCH.REPORTING_DOCS);

-- ---------- Late source-feed anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.LATE_FEED_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, LATE_FEED_PCT::FLOAT AS LATE_FEED
FROM RAW.UNIT_DAILY;
CREATE OR REPLACE VIEW ML.LATE_FEED_TRAIN AS
SELECT * FROM ML.LATE_FEED_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.LATE_FEED_SERIES);
CREATE OR REPLACE VIEW ML.LATE_FEED_DETECT AS
SELECT * FROM ML.LATE_FEED_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.LATE_FEED_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.LATE_FEED_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.LATE_FEED_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'LATE_FEED',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.LATE_FEED_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS LATE_FEED, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.LATE_FEED_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.LATE_FEED_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'LATE_FEED'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.REGREPORT_ANALYTICS
  TABLES (
    units AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per reporting unit, 90-day totals',
    risk AS ML.ERROR_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day material-error probability per reporting unit',
    rules AS CURATED.RULE_SUMMARY PRIMARY KEY (VALIDATION_RULE)
      COMMENT = 'Exceptions, material errors and escalated items by validation rule, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Bank-wide totals per day'
  )
  RELATIONSHIPS (risk_unit AS risk (ENTITY_ID) REFERENCES units)
  FACTS (
    units.exceptions_f AS EXCEPTION_COUNT,
    units.errors_f AS MATERIAL_ERROR_COUNT,
    units.escalated_f AS ESCALATED_COUNT,
    units.records_f AS RECORD_COUNT,
    units.checks_f AS CHECK_COUNT,
    units.balance_f AS BALANCE_PHP,
    units.signoff_due_f AS SIGNOFF_DUE,
    units.signoff_done_f AS SIGNOFF_COMPLETED,
    risk.error_prob_f AS ERROR_PROB_7D,
    rules.rule_exceptions_f AS EXCEPTION_COUNT,
    rules.rule_errors_f AS MATERIAL_ERROR_COUNT,
    rules.rule_escalated_f AS ESCALATED_COUNT,
    rules.rule_balance_f AS FLAGGED_BALANCE_PHP,
    daily.day_exceptions_f AS EXCEPTION_COUNT,
    daily.day_errors_f AS MATERIAL_ERROR_COUNT,
    daily.day_records_f AS RECORD_COUNT
  )
  DIMENSIONS (
    units.unit_id AS ENTITY_ID WITH SYNONYMS = ('reporting unit', 'unit', 'business unit', 'entity'),
    units.unit_name AS ENTITY_NAME,
    units.report_domain AS REPORT_DOMAIN WITH SYNONYMS = ('report domain', 'return type', 'report family'),
    units.region AS REGION WITH SYNONYMS = ('city', 'regional hub', 'location'),
    units.on_remediation_plan AS ON_REMEDIATION_PLAN COMMENT = '1 if the unit is on an internal data-quality remediation plan',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    rules.validation_rule AS VALIDATION_RULE WITH SYNONYMS = ('rule', 'check', 'edit check'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    units.unit_count AS COUNT(units.unit_id) WITH SYNONYMS = ('number of reporting units', 'unit count', 'entities'),
    units.exception_precision_pct AS 100 * SUM(units.errors_f) / NULLIF(SUM(units.exceptions_f), 0)
      COMMENT = 'Material errors / exceptions raised',
    units.exceptions_raised AS SUM(units.exceptions_f) WITH SYNONYMS = ('exceptions', 'exception volume'),
    units.material_errors AS SUM(units.errors_f) WITH SYNONYMS = ('confirmed exceptions', 'reporting errors', 'errors'),
    units.items_escalated AS SUM(units.escalated_f) WITH SYNONYMS = ('escalations', 'escalated items'),
    units.records_submitted AS SUM(units.records_f) WITH SYNONYMS = ('records', 'rows submitted'),
    units.validation_checks AS SUM(units.checks_f),
    units.total_balance_php AS SUM(units.balance_f) WITH SYNONYMS = ('balances', 'reported balance'),
    units.signoff_compliance_pct AS 100 * SUM(units.signoff_done_f) / NULLIF(SUM(units.signoff_due_f), 0)
      COMMENT = 'Controller sign-offs completed / sign-offs due',
    risk.avg_error_prob AS AVG(risk.error_prob_f),
    rules.rule_exceptions AS SUM(rules.rule_exceptions_f),
    rules.rule_errors AS SUM(rules.rule_errors_f),
    rules.rule_escalated AS SUM(rules.rule_escalated_f),
    rules.rule_precision_pct AS 100 * SUM(rules.rule_errors_f) / NULLIF(SUM(rules.rule_exceptions_f), 0),
    daily.daily_exceptions AS SUM(daily.day_exceptions_f),
    daily.daily_errors AS SUM(daily.day_errors_f),
    daily.daily_records AS SUM(daily.day_records_f)
  )
  COMMENT = 'Synthetic Philippine bank regulatory-reporting data-quality analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.REGREPORT_AGENT
  COMMENT = 'Regulatory-reporting data-quality assistant over a synthetic Philippine bank'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give reporting unit IDs and numbers with units. Do not state BSP or other regulatory requirements; refer to the bank's internal SOPs."
  orchestration: "Use regreport_analyst for reporting units, regions, report domains, exceptions, material errors, escalated items, exception precision, sign-off compliance, validation rules and material-error risk. Use sop_search for exception-handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: regreport_analyst
      description: "Reporting units, regions, report domains, exceptions, material errors, escalated items, exception precision, records submitted, balances validated (PHP), sign-off compliance, validation rules and material-error risk scores"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic exception-handling SOPs by report domain and validation rule"
tool_resources:
  regreport_analyst:
    semantic_view: __DEMO_DB__.APP.REGREPORT_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.REPORTING_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-event alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), UNIT_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, SOURCE_SYSTEM VARCHAR, FAILED_CHECKS NUMBER, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_BANKING_BSP_REGULATORY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (UNIT_ID, EVENT_TS, SOURCE_SYSTEM, FAILED_CHECKS, SOP_HINT)
    SELECT t.UNIT_ID, t.EVENT_TS, t.SOURCE_SYSTEM, t.FAILED_CHECKS,
           'Check ' || e.REPORT_DOMAIN || ' SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_EVENTS t
    JOIN RAW.REPORTING_UNITS e ON e.ID = t.UNIT_ID
    LEFT JOIN ML.ERROR_RISK_SCORES r ON r.ENTITY_ID = t.UNIT_ID
    WHERE t.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.UNIT_ID = t.UNIT_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_BANKING_BSP_REGULATORY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Regulatory-reporting feed alert',
      'New failed source-feed loads logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_EVENT_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_EVENTS t
    WHERE t.STATUS = 'ALERT'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.UNIT_ID = t.UNIT_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.RULE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.ERROR_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.ERROR_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.ERROR_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'REPORT_DOMAIN', REPORT_DOMAIN, 'ON_REMEDIATION_PLAN', ON_REMEDIATION_PLAN, 'YEARS_ON_PLATFORM', YEARS_ON_PLATFORM,
             'LATE_FEED_PCT', LATE_FEED_PCT, 'RECON_VARIANCE_RATE', RECON_VARIANCE_RATE,
             'LATE_FEED_7D', LATE_FEED_7D, 'ERRORS_30D', ERRORS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:ERROR::FLOAT, 4) AS ERROR_PROB_7D,
         CASE WHEN PRED:probability:ERROR::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:ERROR::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
