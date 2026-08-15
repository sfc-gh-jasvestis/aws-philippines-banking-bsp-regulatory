-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.BSP_CIRCULAR_SEARCH
  ON CIRCULAR_TEXT
  ATTRIBUTES CIRCULAR_NUMBER, CATEGORY, EFFECTIVE_DATE, IMPACT_AREA
  WAREHOUSE = COMPLIANCE_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.BSP_CIRCULARS
);
