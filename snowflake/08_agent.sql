-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for BSP Regulatory Reporting & Compliance Automation
-- ============================================================================
USE DATABASE REGULATORY_REPORTING;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.COMPLIANCE_INTELLIGENCE_AGENT
  COMMENT = 'BSP Regulatory Reporting & Compliance Automation AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'REGULATORY_REPORTING.APP.COMPLIANCE_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'REGULATORY_REPORTING.SEARCH.BSP_CIRCULAR_SEARCH', TOOL_DESCRIPTION => 'Search documents for Banking & Insurance information')
  )
  SYSTEM_PROMPT = 'You are the Regulatory Compliance Agent for a Philippine universal bank submitting 210+ reports to BSP quarterly, managing 280 exam findings, and tracking 450 BSP circulars.';
