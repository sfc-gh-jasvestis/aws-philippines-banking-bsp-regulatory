# BSP Regulatory Reporting & Compliance Automation

**Philippines - Banking & Insurance**
Use case: Regulatory Reporting

> Philippine banks submit 200+ reports to BSP quarterly — Snowflake automates regulatory data preparation with Task Graphs, parses regulatory circulars with AI, and enables compliance teams to query requirements in natural language.

## Why Snowflake

Snowflake processes regulatory documents via Textract + AI_PARSE_DOCUMENT, orchestrates report generation with Step Functions-equivalent Task Graphs, and provides Cortex Search on BSP circulars — transforming manual compliance into automated pipelines

- **AI_PARSE_DOCUMENT on BSP circulars** - Only demo extracting regulatory requirements from Philippine regulatory documents
- **Task Graphs replacing Step Functions** - Multi-step report generation pipeline orchestrated natively in Snowflake
- **Cortex Search on 450 BSP circulars** - Natural language queries across Philippine banking regulations
- **ML.CLASSIFICATION predicting report failures** - Proactive quality — predicts which reports will fail validation before filing
- **BSP-specific regulatory context** - Philippine banking regulations (DOSRI, CAMEL, FRP, capital adequacy)
- **Reconciliation anomaly detection** - ML.ANOMALY_DETECTION catches data quality issues between source systems

## What is deployed

| | |
|---|---|
| Database | `PH_BANKING_BSP_REGULATORY` |
| Service | `PH_BANKING_BSP_REGULATORY_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.REPORT_CATALOG` (20 rows) |
| Fact table | `RAW.FINANCIAL_DATA` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: FRP Report, AMLC Report, Basel III, Consumer Protection

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_BANKING_BSP_REGULATORY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| CAR Ratio | `16.8%` | average per event |
| LCR | `142%` | average per event |
| BSP Findings Open | `4` | total across Report Catalog |
| Reports Submitted | `247` | total across Report Catalog |
| Stress CAR (Severe) | `12.4%` | average per event |
| Credit Loss (Severe) | `₱18B` | total across Report Catalog |
| Liquidity Buffer | `₱42B` | total across Report Catalog |


## Demo flow

1. Executive Cockpit
2. Report Readiness
3. Circular Compliance
4. Ask AI
5. Architecture & Data

## Talking points

- **210 reports** - regulatory filings due per quarter
- **38 reports** - due within next 2 weeks
- **12 reports** - predicted to fail BSP validation (ML.CLASSIFICATION)
- **450 circulars** - parsed and searchable via Cortex Search
- **14 findings** - outstanding BSP exam findings
- **4 hours** - automated report generation (vs 3 days manual)

## Business impact

- Philippine banks face ₱500K-₱10M penalties per report filing violation (BSP)
- Banks spend 40-60% of compliance budget on manual regulatory reporting (Deloitte RegTech)
- Automated regulatory reporting reduces errors by 70-90% and cost by 50% (McKinsey Banking)
- BSP supervises 500+ banks and issues 50-80 new circulars annually (BSP)

---
Generated from `generator/demo_specs/aws-philippines-banking-bsp-regulatory.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-banking-bsp-regulatory` instead.
