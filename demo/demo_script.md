# Demo Script: BSP Regulatory Reporting & Compliance Automation
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake processes regulatory documents via Textract + AI_PARSE_DOCUMENT, orchestrates report generation with Step Functions-equivalent Task Graphs, and provides Cortex Search on BSP circulars — transforming manual compliance into automated pipelines"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Atty. Corazon Mercedes Aquino** | Chief Compliance Officer | React App (SPCS) | Regulatory exam readiness, report accuracy, filing deadlines, BSP findings remediation |
| **Fernando Jose Ramirez** | Regulatory Reporting Manager | Amazon QuickSight | Data quality for reports, reconciliation gaps, automation coverage, error rates |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | REPORT_CATALOG (210), SUBMISSION_HISTORY (4800), FINANCIAL_DATA (8500000), BSP_CIRCULARS (450), EXAM_FINDINGS (280), RECONCILIATION_DATA (1200000), VALIDATION_RULES (3500) |
| **CURATED** | 4 Dynamic Tables | REPORT_READINESS, RECONCILIATION_STATUS, FINDING_TRACKER, COMPLIANCE_CALENDAR |
| **ML** | ML.CLASSIFICATION + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | AI_PARSE_DOCUMENT, AI_CLASSIFY, COMPLETE | Classification + extraction |
| **Search** | Cortex Search | 450 documents indexed |
| **Agent** | COMPLIANCE_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

Philippine banks submit 200+ regulatory reports to BSP every quarter — Financial Reporting Package, CAMEL ratings, DOSRI disclosures, capital adequacy, liquidity coverage, stress tests, and more. One universal bank's compliance team of 45 people spends 60% of their time on manual data preparation. Reports still fail BSP validation 15% of the time, triggering exam findings. Snowflake automates the entire pipeline while AI makes 450 BSP circulars instantly searchable.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "210 regulatory reports due this quarter — 38 reports due within next 2 weeks."

**Action**: Point at 210 reports dashboard

### [0:45–1:30] REPORT READINESS

**Show**: Report Readiness tab

> "ML.CLASSIFICATION predicts 12 reports likely to fail BSP validation this cycle."

**Action**: Show predicted failure reports in amber/red

### [1:30–2:15] CIRCULAR COMPLIANCE

**Show**: Circular Compliance tab

> "AI_PARSE_DOCUMENT processed 450 BSP circulars — extracting requirements, deadlines, impact areas."

**Action**: Show parsed circular with extracted requirements

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Atty. Aquino asks: 'Which reports failed validation last quarter?'"

**Action**: Type: 'Reports that failed last quarter?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Textract → AI_PARSE_DOCUMENT for circulars. Step Functions → Task Graphs for report generation."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **AI_PARSE_DOCUMENT on BSP circulars** — Only demo extracting regulatory requirements from Philippine regulatory documents
2. **Task Graphs replacing Step Functions** — Multi-step report generation pipeline orchestrated natively in Snowflake
3. **Cortex Search on 450 BSP circulars** — Natural language queries across Philippine banking regulations
4. **ML.CLASSIFICATION predicting report failures** — Proactive quality — predicts which reports will fail validation before filing
5. **BSP-specific regulatory context** — Philippine banking regulations (DOSRI, CAMEL, FRP, capital adequacy)
6. **Reconciliation anomaly detection** — ML.ANOMALY_DETECTION catches data quality issues between source systems


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.RAW.FINANCIAL_DATA` → 8500000
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.RAW.BSP_CIRCULARS` → 450
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.CURATED.REPORT_READINESS WHERE READINESS_SCORE < 80` → >=12

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.ML.REPORT_ERROR_PREDICTION WHERE WILL_FAIL_VALIDATION = TRUE` → 12
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.ML.DATA_QUALITY_ANOMALY_RESULTS WHERE IS_ANOMALY = TRUE` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM REGULATORY_REPORTING.AI.PARSED_CIRCULARS` → 450

