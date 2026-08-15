-- ============================================================================
-- BSP Regulatory Reporting & Compliance Automation
-- Philippine banks submit 200+ reports to BSP quarterly — Snowflake automates regulatory data preparation with Task Graphs, parses regulatory circulars with AI, and enables compliance teams to query requirements in natural language.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS REGULATORY_REPORTING;
CREATE WAREHOUSE IF NOT EXISTS COMPLIANCE_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE REGULATORY_REPORTING;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE COMPLIANCE_WH;
