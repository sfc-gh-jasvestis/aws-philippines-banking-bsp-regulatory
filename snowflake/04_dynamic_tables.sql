-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA CURATED;

-- REPORT_READINESS: Real-time report generation readiness with data quality scores
-- Source: REPORT_CATALOG, FINANCIAL_DATA, VALIDATION_RULES
CREATE OR REPLACE DYNAMIC TABLE CURATED.REPORT_READINESS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = COMPLIANCE_WH
AS
SELECT * FROM RAW.REPORT_CATALOG;
-- TODO: Replace with actual join/aggregation logic per demo

-- RECONCILIATION_STATUS: Cross-system reconciliation gaps and resolution tracking
-- Source: RECONCILIATION_DATA, FINANCIAL_DATA
CREATE OR REPLACE DYNAMIC TABLE CURATED.RECONCILIATION_STATUS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = COMPLIANCE_WH
AS
SELECT * FROM RAW.RECONCILIATION_DATA;
-- TODO: Replace with actual join/aggregation logic per demo

-- FINDING_TRACKER: BSP exam findings with remediation progress
-- Source: EXAM_FINDINGS, SUBMISSION_HISTORY
CREATE OR REPLACE DYNAMIC TABLE CURATED.FINDING_TRACKER
  TARGET_LAG = '5 minutes'
  WAREHOUSE = COMPLIANCE_WH
AS
SELECT * FROM RAW.EXAM_FINDINGS;
-- TODO: Replace with actual join/aggregation logic per demo

-- COMPLIANCE_CALENDAR: Upcoming filing deadlines with readiness status
-- Source: REPORT_CATALOG, SUBMISSION_HISTORY
CREATE OR REPLACE DYNAMIC TABLE CURATED.COMPLIANCE_CALENDAR
  TARGET_LAG = '5 minutes'
  WAREHOUSE = COMPLIANCE_WH
AS
SELECT * FROM RAW.REPORT_CATALOG;
-- TODO: Replace with actual join/aggregation logic per demo

