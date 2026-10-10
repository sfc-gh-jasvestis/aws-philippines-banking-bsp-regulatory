import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, rules, units, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; ALERTS: number | null; CONFIRMED: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               EXCEPTION_COUNT AS ALERTS, MATERIAL_ERROR_COUNT AS CONFIRMED
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ RULE: string; ALERTS: number; CONFIRMED: number }>(`
        SELECT VALIDATION_RULE AS RULE, EXCEPTION_COUNT AS ALERTS, MATERIAL_ERROR_COUNT AS CONFIRMED
        FROM CURATED.RULE_SUMMARY ORDER BY MATERIAL_ERROR_COUNT DESC, EXCEPTION_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, REPORT_DOMAIN, ON_REMEDIATION_PLAN, EVENT_COUNT, EXCEPTION_COUNT, MATERIAL_ERROR_COUNT,
               ESCALATED_COUNT, EXCEPTION_PRECISION_PCT, SIGNOFF_COMPLIANCE_PCT, ROUND(BALANCE_PHP / 1e6, 1) AS BALANCE_PHP_M
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.UNIT_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, ERROR_PROB_7D, RISK_BAND
        FROM ML.ERROR_RISK_SCORES ORDER BY ERROR_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.ERROR_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, EXCEPTION_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.EXCEPTION_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT UNIT_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, SOURCE_SYSTEM, ROUND(BALANCE_PHP, 0) AS BALANCE_PHP,
               FAILED_CHECKS, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_EVENTS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'ALERT') AS ALERTS,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_EVENTS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(LATE_FEED, 2) AS LATE_FEED,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.LATE_FEED_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT UNIT_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, SOURCE_SYSTEM,
               FAILED_CHECKS, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, alerts: numberOrNull(row.ALERTS), errors: numberOrNull(row.CONFIRMED) })),
      categories: rules.map((row) => ({ category: row.RULE, alerts: numberOrNull(row.ALERTS), errors: numberOrNull(row.CONFIRMED) })),
      entities: units.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, report_domain: row.REPORT_DOMAIN, plan: Number(row.ON_REMEDIATION_PLAN) === 1 ? 'Yes' : 'No',
        alerts: numberOrNull(row.EXCEPTION_COUNT), errors: numberOrNull(row.MATERIAL_ERROR_COUNT), escalated: numberOrNull(row.ESCALATED_COUNT),
        precision: numberOrNull(row.EXCEPTION_PRECISION_PCT), balance: numberOrNull(row.BALANCE_PHP_M),
        signoff: numberOrNull(row.SIGNOFF_COMPLIANCE_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      signoffRisk: units.map((row) => ({
        name: row.ENTITY_NAME, compliance: numberOrNull(row.SIGNOFF_COMPLIANCE_PCT), errors: numberOrNull(row.MATERIAL_ERROR_COUNT),
      })).filter((row) => row.compliance !== null && row.errors !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.ERROR_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.EXCEPTION_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.UNIT_ID, eventTs: row.EVENT_TS, source_system: row.SOURCE_SYSTEM, balance: numberOrNull(row.BALANCE_PHP),
        failed: numberOrNull(row.FAILED_CHECKS), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), alerts: numberOrNull(liveSummary[0]?.ALERTS),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, lateFeed: numberOrNull(row.LATE_FEED),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.UNIT_ID, eventTs: row.EVENT_TS, source_system: row.SOURCE_SYSTEM,
        failed: numberOrNull(row.FAILED_CHECKS), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Regulatory-reporting data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
