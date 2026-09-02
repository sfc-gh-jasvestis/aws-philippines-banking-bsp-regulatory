-- Generated from generator/demo_specs/aws-philippines-banking-bsp-regulatory.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-banking-bsp-regulatory
-- This is the schema that is actually deployed for PH_BANKING_BSP_REGULATORY.

-- PH_BANKING_BSP_REGULATORY  (BSP Regulatory Reporting & Compliance Automation)
-- generated from generator/demo_specs/aws-philippines-banking-bsp-regulatory.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_BANKING_BSP_REGULATORY;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_BSP_REGULATORY.RAW;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_BSP_REGULATORY.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_BSP_REGULATORY.APP;
USE DATABASE PH_BANKING_BSP_REGULATORY;

-- 5 real regions; entity names carry their region so the two always agree
