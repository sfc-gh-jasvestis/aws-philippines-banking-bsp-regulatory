-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_banking_bsp_regulatory_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: DEADLINE_ALERT
CREATE OR REPLACE ALERT APP.DEADLINE_ALERT
  WAREHOUSE = COMPLIANCE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Report approaching deadline with low readiness score'
IF (EXISTS (
  SELECT 1 FROM CURATED.REPORT_READINESS
  WHERE 1=1 -- Condition: REPORT_DUE_IN_DAYS < 3 AND READINESS_SCORE < 80
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_banking_bsp_regulatory_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] BSP Regulatory Reporting & Compliance Automation: Report approaching deadline with low readiness score',
    'Report approaching deadline with low readiness score'
  );

ALTER ALERT APP.DEADLINE_ALERT RESUME;

-- Alert: RECONCILIATION_GAP_ALERT
CREATE OR REPLACE ALERT APP.RECONCILIATION_GAP_ALERT
  WAREHOUSE = COMPLIANCE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Reconciliation gap exceeding ₱1M threshold'
IF (EXISTS (
  SELECT 1 FROM CURATED.REPORT_READINESS
  WHERE 1=1 -- Condition: UNRESOLVED_GAP > 1000000 for any system pair
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_banking_bsp_regulatory_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] BSP Regulatory Reporting & Compliance Automation: Reconciliation gap exceeding ₱1M threshold',
    'Reconciliation gap exceeding ₱1M threshold'
  );

ALTER ALERT APP.RECONCILIATION_GAP_ALERT RESUME;

