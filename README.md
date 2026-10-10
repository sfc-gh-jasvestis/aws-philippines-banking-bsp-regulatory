# Philippine Bank Regulatory Reporting Data Quality

End-to-end data-quality control for the regulatory returns of **a fictional Philippine universal bank**, across **40 reporting units in 5 regional hubs** (Makati City, Cebu City, Davao City, Iloilo City and Cagayan de Oro) and 5 report domains (Loans and credit, Deposits, Capital adequacy, Liquidity, Financial statements), using Snowflake, optionally with AWS: from a live source-feed load that fails its validation checks to a 7-day material-error risk score, an alert email and an AI action memo for the Head of Regulatory Reporting. The validation rules, SOPs and sign-off policy are synthetic internal policies of the fictional bank; they are not Bangko Sentral ng Pilipinas (BSP) text or guidance, and the demo makes no statement about BSP requirements.

## Architecture

A regulatory-reporting data-quality pipeline built on **Snowflake** (Dynamic Tables, Snowflake ML, Cortex Search, Cortex Agent, Cortex AI_COMPLETE, SPCS) and, in the full build, **AWS** (Amazon Data Firehose, S3, Bedrock Claude, QuickSight + Amazon Q). Source-system feed loads land in `RAW.LIVE_EVENTS`. Dynamic tables curate 90 days of reporting-unit-day history: validation exceptions raised, material errors confirmed, items escalated, exception precision, controller sign-off compliance and source-feed mapping coverage. Snowflake ML scores 7-day material-error risk per reporting unit, forecasts bank-wide exception volume and flags late source-feed anomalies. A Cortex Agent answers questions with SOP citations, and an LLM drafts the action memo.

Interactive diagrams (hover for object names): [Snowflake only](docs/architecture-snowflake.html) | [AWS + Snowflake](docs/architecture-aws.html). The app shows both on its Architecture & Data tab, the current build first. Regenerate them with `python3 docs/build_architecture.py`.

```mermaid
flowchart LR
    subgraph AWS
      SIM[publish_events.py] --> FH[Amazon Data Firehose<br/>stream ph-banking-bsp-regulatory-events]
      FH -->|batched JSON| S3[(Amazon S3<br/>events/ landing)]
      BR[Amazon Bedrock<br/>Claude Sonnet 4.5]
      QS[Amazon QuickSight<br/>dashboard + Q topic]
    end
    subgraph Snowflake
      S3 -->|SQS event| PIPE[Snowpipe AUTO_INGEST] --> LIVE[RAW.LIVE_EVENTS]
      GEN[02_raw_tables.sql<br/>seeded generator] --> RAW[RAW.REPORTING_UNITS / UNIT_DAILY / SOURCE_FEEDS]
      RAW --> DT[CURATED dynamic tables]
      RAW --> ML[Snowflake ML<br/>CLASSIFICATION risk, FORECAST,<br/>ANOMALY_DETECTION]
      DT --> SV[Semantic view<br/>APP.REGREPORT_ANALYTICS]
      RAW --> CS[Cortex Search<br/>exception-handling SOPs]
      SV --> AG[Cortex Agent<br/>APP.REGREPORT_AGENT]
      CS --> AG
      LIVE --> AL[Alert APP.LIVE_EVENT_ALERT<br/>+ email]
      UDF[APP.BEDROCK_GENERATE<br/>external access UDF]
      TK[Task graph: refresh, then rescore]
      APP[Next.js app on SPCS]
    end
    BR <--> UDF
    DT --> APP
    ML --> APP
    LIVE --> APP
    AG --> APP
    UDF --> APP
    DT --> QS
    ML --> QS
    LIVE --> QS
```

The Snowflake-only build drops the AWS subgraph: `APP.SIMULATE_EVENTS` writes to `RAW.LIVE_EVENTS`, and the app calls Cortex `AI_COMPLETE` instead of the Bedrock UDF.

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `RULE_SUMMARY`, `TREND_ANALYSIS` from the RAW tables |
| Snowflake ML | CLASSIFICATION 7-day material-error risk (`ML.ERROR_RISK_SCORES`), 14-day exception-volume FORECAST, late source-feed ANOMALY_DETECTION |
| Cortex Search | 14 synthetic exception-handling SOPs (one per report domain and validation rule) in `SEARCH.REPORTING_SOP_SEARCH` |
| Semantic View | `APP.REGREPORT_ANALYTICS` over reporting units, validation rules, daily totals and risk |
| Cortex Agent | `APP.REGREPORT_AGENT`: Cortex Analyst over the semantic view plus Cortex Search for SOP citations |
| Cortex AI | `AI_COMPLETE('claude-sonnet-4-5')` for grounded answers, and for the action memo in the Snowflake-only build |
| Alerts + Tasks | `APP.LIVE_EVENT_ALERT` logs ALERT feed loads and sends email; task graph `TASK_REFRESH_CURATED`, then `TASK_RESCORE_RISK` |
| Snowpark Container Services | Next.js app `APP.PH_BANKING_BSP_REGULATORY_APP` with 6 tabs: Executive Cockpit, Predictive, Sign-off & Lineage, Live Feed, Ask AI, Architecture & Data |
| Snowpipe | `RAW.LIVE_EVENTS_PIPE` AUTO_INGEST from S3 (AWS build only) |

## AWS Services

Used only in the AWS + Snowflake build.

| Service | Role in Demo |
|---------|-------------|
| Amazon Data Firehose | Direct PUT stream `ph-banking-bsp-regulatory-events` receives simulated source-feed load events and writes batches to S3 |
| Amazon S3 | Landing bucket (`events/`). An event notification goes to the Snowpipe SQS queue |
| Amazon Bedrock | Claude Sonnet 4.5 writes the action memo, called from Snowflake through an external-access UDF |
| Amazon QuickSight | DIRECT_QUERY executive dashboard over Snowflake (daily exceptions, material errors by reporting unit, material-error risk) |
| Amazon Q | Natural-language questions over the QuickSight topic `ph-banking-bsp-regulatory-topic` |
| AWS IAM | Least-privilege roles for S3, Firehose and Bedrock |

## Personas

These personas are fictional.

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Andrea Dizon** | Head of Regulatory Reporting | "What is our exception precision?" "Which validation rules find the most material errors?" "Are controller sign-offs and source-feed mapping keeping up?" |
| **Paolo Ramos** | Regulatory Reporting Data Analyst | "Which reporting units are high risk this week, and which SOP applies?" |

## Data

All data is synthetic and seeded, so every rebuild reproduces it. The bank, reporting units and names are fictional; the regional hubs are real Philippine cities used only as labels.

| Table | Rows | Description |
|-------|------|-------------|
| RAW.REPORTING_UNITS | 40 | Reporting units across 5 regional hubs and 5 report domains, with remediation-plan flag and years on the current reporting platform |
| RAW.UNIT_DAILY | 3,600 | Daily reporting-unit observations over 90 days: records submitted, validation checks run, balances validated (PHP), exceptions, material errors, escalated items, validation rule, controller sign-off, late source-feed share and reconciliation variance rate |
| RAW.SOURCE_FEEDS | 40 | Required, mapped and pending source-system feeds per reporting unit |
| SEARCH.REPORTING_DOCS | 14 | Synthetic exception-handling SOPs indexed for Cortex Search |
| RAW.LIVE_EVENTS | Grows during the demo | Live source-feed load events from Firehose (AWS build) or `APP.SIMULATE_EVENTS` (Snowflake-only build) |
| ML.ERROR_RISK_SCORES | 40 | 7-day material-error probability and risk band per reporting unit |

## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access, and Cortex AI enabled (AI_COMPLETE, Search, Agent).
- An X-Small warehouse with auto-suspend at or below 120 s, and an existing SPCS compute pool.
- Python 3.11+, `snowflake-connector-python`, Node.js 22+, Docker and the `snow` CLI.
- App image: run `snow spcs image-registry login`, then build and push `ph-banking-bsp-regulatory-app:v1` to the database's `APP.IMAGES` repository (see the header of `snowflake/07_deploy_app.sql`).
- AWS build only: `boto3`, AWS credentials for the target account (us-west-2) with Bedrock access, and QuickSight Enterprise.

### SPCS App
```
<DATABASE>.APP.PH_BANKING_BSP_REGULATORY_APP
```

### Tests
```bash
python -m pytest aws snowflake quicksight
```

For a local run, put `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_AUTHENTICATOR=PROGRAMMATIC_ACCESS_TOKEN`, `SNOWFLAKE_TOKEN` and `DEMO_PLATFORM` in the environment, then run `npm --prefix app run build && npm --prefix app start`.

## Build Modes

Both modes share the same core. They differ in three places, and the app's `DEMO_PLATFORM` setting (in its SPCS spec) switches the memo provider and the Live Feed tab.

| Layer | Snowflake Only | Full AWS + Snowflake |
|---|---|---|
| Live events | `CALL APP.SIMULATE_EVENTS(n)` inserts simulated source-feed load events into `RAW.LIVE_EVENTS`. This simulates an event feed; it is not Snowpipe Streaming | `aws/publish_events.py` to Amazon Data Firehose, then S3, SQS and Snowpipe AUTO_INGEST |
| Action memo | Cortex `AI_COMPLETE('claude-sonnet-4-5')` | Amazon Bedrock Claude Sonnet 4.5 through `APP.BEDROCK_GENERATE` |
| BI and natural-language questions | The SPCS app is the dashboard; questions go to the Cortex Agent | Also a QuickSight dashboard and an Amazon Q topic |
| App setting | `DEMO_PLATFORM: snowflake` | `DEMO_PLATFORM: aws` |

### Snowflake Only

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_BANKING_BSP_REGULATORY_SNOWFLAKE --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. Native event feed, ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_BSP_REGULATORY_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 3. App on SPCS with DEMO_PLATFORM=snowflake (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_BSP_REGULATORY_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
```

During the demo:
- Run `CALL APP.SIMULATE_EVENTS(20)` to add live source-feed load events. For a continuous feed, run `ALTER TASK APP.TASK_SIMULATE_EVENTS RESUME`, and `SUSPEND` it afterwards.
- Run `EXECUTE ALERT APP.LIVE_EVENT_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore risk.

Afterwards, drop the database or run `ALTER SERVICE APP.PH_BANKING_BSP_REGULATORY_APP SUSPEND`.

### Full AWS + Snowflake

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. AWS ingestion and Bedrock (dry run first, then --apply)
python aws/setup_aws.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply
# 3. ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 4. App on SPCS with DEMO_PLATFORM=aws (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
# 5. QuickSight dashboard and Q topic (needs an existing Snowflake data source)
python quicksight/build_dashboards.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --account <AWS_ACCOUNT_ID> --principal-arn <QUICKSIGHT_USER_ARN> --data-source-arn <DATA_SOURCE_ARN> --prefix ph-banking-bsp-regulatory --apply --update --with-topic
```

QuickSight objects must be shared with the QuickSight user who signs in (`--principal-arn`); otherwise the console shows nothing.

During the demo:
- Run `python aws/publish_events.py --count 20` to send live source-feed load events. Firehose buffers for up to 60 seconds before writing to S3.
- Run `EXECUTE ALERT APP.LIVE_EVENT_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore risk.

Afterwards, `python aws/teardown_aws.py --database PHILIPPINES_BANKING_BSP_REGULATORY_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply` removes the AWS resources and the account-level Bedrock external-access and S3 storage integrations. It leaves the email integration `PH_BANKING_BSP_REGULATORY_EMAIL_INT`, which the Snowflake-only build also uses.

## Business Impact

Industry research and Snowflake customer outcomes:
- **98% of financial institutions** reported an increase in financial crime compliance costs -- [LexisNexis Risk Solutions and Forrester Consulting, True Cost of Financial Crime Compliance Global Study, 2023](https://risk.lexisnexis.com/insights-resources/research/true-cost-of-financial-crime-compliance-study-global-report)
- **FIS** (Snowflake customer) rebuilt its capital markets Compliance Suite, which covers communications surveillance, anti-money laundering and regulatory reporting, on Snowflake: compliance data processed up to 20 times faster, client data loaded seven times faster with a fourfold improvement in its error correction process, and severity 1 and 2 incidents down 68% -- [Snowflake customer story: FIS](https://www.snowflake.com/en/customers/all-customers/case-study/fis/)

## Key Demo Numbers

These figures are synthetic and come from the seeded demo data. Forecast and anomaly figures can shift slightly with the build day.

- **40 reporting units**, 3,600 unit-days over 90 days, across 5 regional hubs and 5 report domains (11 on a remediation plan); 423,389 records submitted and PHP 1,871 B of balances validated
- **627 exceptions** raised and **195 confirmed** as material errors, so exception precision is 31.1%; **96 items escalated**
- **GL-to-report variance** finds the most material errors (45 of 195); the 25 upstream batch delay exceptions are never material errors
- **Material-error model** out-of-time holdout: precision 0.70, recall 0.42 at a 0.5 threshold, against a 0.29 base rate. Six reporting units are high risk; the top unit is RU-0016, at 92.8%
- **14-day exception forecast** with prediction intervals; **35 of 640** unit-days flagged as late source-feed anomalies
- **Sign-off compliance 82.2%**, feed mapping coverage 57.7%, with 21 source feeds pending mapping
- **14 SOPs** indexed for Cortex Search and cited by ID in agent answers

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty. Industry metrics cited are from publicly available third-party research and Snowflake customer stories; they represent reported outcomes and are not guarantees of results.
