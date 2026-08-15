-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_EXTRACT_GL
  WAREHOUSE = COMPLIANCE_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  COMMENT = 'Extract latest GL data for report generation'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_VALIDATE_DATA
  WAREHOUSE = COMPLIANCE_WH
  AFTER APP.TASK_EXTRACT_GL
  COMMENT = 'Run BSP validation rules against extracted data'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_GENERATE_REPORTS
  WAREHOUSE = COMPLIANCE_WH
  AFTER APP.TASK_VALIDATE_DATA
  COMMENT = 'Generate regulatory reports for filing'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_RECONCILE
  WAREHOUSE = COMPLIANCE_WH
  AFTER APP.TASK_GENERATE_REPORTS
  COMMENT = 'Run cross-system reconciliation checks'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_RECONCILE RESUME;
ALTER TASK APP.TASK_GENERATE_REPORTS RESUME;
ALTER TASK APP.TASK_VALIDATE_DATA RESUME;
ALTER TASK APP.TASK_EXTRACT_GL RESUME;
