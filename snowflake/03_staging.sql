-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for BSP Regulatory Reporting & Compliance Automation
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- REPORT_CATALOG: 210 rows — BSP report definitions (FRP, CAMEL, DOSRI, stress testing, etc.)
-- SUBMISSION_HISTORY: 4,800 rows — 3 years of report submissions with status and findings
-- FINANCIAL_DATA: 8,500,000 rows — General ledger and subledger data for report generation
-- BSP_CIRCULARS: 450 rows — BSP circulars, memoranda, and regulatory requirements
-- EXAM_FINDINGS: 280 rows — BSP examination findings with remediation status
-- RECONCILIATION_DATA: 1,200,000 rows — Cross-system reconciliation records
-- VALIDATION_RULES: 3,500 rows — BSP data validation rules per report type
