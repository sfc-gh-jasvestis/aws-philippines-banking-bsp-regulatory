# Regulatory Reporting Data Quality

**Philippines - Banking**
Use case: Data-quality control for regulatory returns, controller sign-off and source-feed lineage

> Data-quality control for 40 reporting units across 5 regional hubs at a fictional Philippine universal bank: dynamic tables, a holdout-evaluated material-error classifier, an exception-volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile exceptions, material errors, escalated items, controller sign-off compliance and feed mapping coverage from RAW data, with checks in `run_core.py`
- **Material-error classification** gives a holdout-evaluated next-7-day probability per reporting unit
- **Exception forecast** projects 14 days of bank-wide exception volume with prediction intervals, for reporting-team staffing
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live feed**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.REPORTING_UNITS` (40 rows) |
| Fact table | `RAW.UNIT_DAILY` (3,600 unit-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `RULE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.ERROR_RISK_SCORES`, `ML.ERROR_RISK_HOLDOUT_METRICS`, `ML.EXCEPTION_FORECAST`, `ML.LATE_FEED_ANOMALIES` |

Regional hubs: Makati City, Cebu City, Davao City, Iloilo City, Cagayan de Oro.
Report domains: Loans and credit, Deposits, Capital adequacy, Liquidity, Financial statements.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Exception Precision | 31.1% |
| Exceptions Raised | 627 |
| Material Errors | 195 |
| Items Escalated | 96 |
| Balances Validated (PHP B) | 1,871 |
| Records Submitted | 423,389 |
| Sign-off Compliance | 82.2% |
| Reporting Units Monitored | 40 |
| Feed Mapping Coverage | 57.7% |
| Feeds Pending Mapping | 21 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily exceptions against material errors, exceptions and material errors by validation rule, reporting-unit table
2. Predictive: holdout metrics, risk bands, 14-day exception forecast, late source-feed anomalies
3. Sign-off & Lineage: controller sign-off compliance, feed mapping coverage and pending feeds, sign-off compliance against material errors, then generate the action memo
4. Live Feed: run `CALL APP.SIMULATE_EVENTS(20)` (Snowflake only) or `python aws/publish_events.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_EVENT_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- About three exceptions in ten are material errors (31.1%). Most exception reviews end as false positives, which is where reporting analyst time goes.
- GL-to-report variance exceptions find the most material errors. Upstream batch delay exceptions hit a whole report domain at once and are never material errors.
- The risk model is evaluated on a time-based holdout: precision 0.70 and recall 0.42 at 0.5, against a 0.29 base rate. Present it as triage, not a verdict.
- Upstream batch delays are excluded from model training, because they are not unit-driven.
- The validation rules, SOPs and sign-off policy are synthetic internal policies of the fictional bank, not BSP text; the demo makes no statement about BSP requirements.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
