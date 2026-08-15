-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.COMPLIANCE_ANALYTICS
  COMMENT = 'Regulatory reporting readiness, BSP findings, reconciliation, and compliance analytics'
AS
  TABLES (
    CURATED.REPORT_READINESS AS report_readiness,CURATED.RECONCILIATION_STATUS AS reconciliation_status,CURATED.FINDING_TRACKER AS finding_tracker,CURATED.COMPLIANCE_CALENDAR AS compliance_calendar
  );
