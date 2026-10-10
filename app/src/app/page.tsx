'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface ComplianceData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; alerts: number | null; errors: number | null }[];
  categories: { category: string; alerts: number | null; errors: number | null }[];
  entities: Record<string, string | number | null>[];
  signoffRisk: { name: string; compliance: number; errors: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; alerts: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<ComplianceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Exception Precision', 'Exceptions Raised', 'Material Errors', 'Items Escalated'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Exception precision = material errors / exceptions raised. An escalated item is a material error passed to the head of regulatory reporting. Exceptions come from the bank's internal validation rules on report data.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'alerts', name: 'Exceptions raised' }, { key: 'errors', name: 'Material errors' }]} title="Daily Exceptions" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'alerts', name: 'Exceptions' }, { key: 'errors', name: 'Material errors' }]} title="Exceptions and Material Errors by Validation Rule" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Reporting unit' }, { key: 'region', header: 'Region' }, { key: 'report_domain', header: 'Report domain' },
        { key: 'plan', header: 'Remediation plan' }, { key: 'alerts', header: 'Exceptions' }, { key: 'errors', header: 'Material errors' },
        { key: 'escalated', header: 'Escalated' }, { key: 'precision', header: 'Exception precision (%)' }, { key: 'balance', header: 'Balances validated (PHP M)' },
      ]} data={data?.entities ?? []} title="Reporting unit observations (90 days)" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day material-error risk and exception-volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a reporting unit has a material reporting error in the next 7 days,
        from late source feeds, reconciliation variance rate, recent material errors, remediation-plan status, years on the current platform and report domain.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} unit-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Reporting unit' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(material error in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Material-error risk by reporting unit" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Bank-wide exception forecast, next 14 days (exceptions per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Reporting unit' }, { key: 'date', header: 'Date' }, { key: 'lateFeed', header: 'Late source feeds (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Late source-feed anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live source-feed loads: Amazon Data Firehose to S3 to Snowpipe' : 'Live source-feed loads: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated source-system feed load events are sent to the Firehose stream ph-banking-bsp-regulatory-events (aws/publish_events.py). Firehose writes batches to S3, and Snowpipe auto-ingest loads them into RAW.LIVE_EVENTS.'
          : 'CALL APP.SIMULATE_EVENTS(n) inserts simulated source-system feed load events directly into RAW.LIVE_EVENTS (or resume APP.TASK_SIMULATE_EVENTS for a feed every minute). This simulates an event feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_EVENT_ALERT logs ALERT events (loads with failed validation checks) and emails the reporting team.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="ALERT events" value={String(data?.liveSummary?.alerts ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Reporting unit' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'source_system', header: 'Source system' },
        { key: 'balance', header: 'Balance loaded (PHP)' }, { key: 'failed', header: 'Failed checks' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 source-feed loads" />
      <DataTable columns={[
        { key: 'id', header: 'Reporting unit' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'source_system', header: 'Source system' },
        { key: 'failed', header: 'Failed checks' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Sign-off Compliance" value={kpiVal('Sign-off Compliance')} />
        <KPICard title="Feed Mapping Coverage" value={kpiVal('Feed Mapping Coverage')} />
        <KPICard title="Feeds Pending Mapping" value={kpiVal('Feeds Pending Mapping')} />
      </div>
      <Chart data={data?.signoffRisk ?? []} type="scatter" xKey="compliance" xName="Sign-off compliance"
        yKeys={[{ key: 'errors', name: 'Material errors' }]} yDomain={[0, 'auto']}
        title="Controller sign-off compliance (%) vs material errors by reporting unit" />
      <p className="text-sm text-slate-600">Feed mapping coverage is the share of required source-system feeds per reporting unit that are mapped to report lines (synthetic internal policy). Synthetic associations are not evidence that sign-offs prevented errors.</p>
      <ActionMemo persona={{ name: 'Andrea Dizon', role: 'Head of Regulatory Reporting (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft regulatory-reporting data-quality actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, reporting-unit, validation-rule and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.REGREPORT_AGENT. It uses Cortex Analyst over the semantic view APP.REGREPORT_ANALYTICS for metrics, and Cortex Search over synthetic exception-handling SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the regulatory-reporting agent" mode="advisor" sampleQuestions={['Which 3 reporting units have the most material errors?', 'Which reporting units are high risk this week and what SOP applies?', 'What is exception precision by validation rule?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic reporting units, daily reporting-unit data-quality observations and source-feed mapping records. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION material-error risk model evaluated on a time-based holdout, plus a 14-day exception-volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags late source-feed outliers per reporting unit over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: Amazon Data Firehose to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_EVENTS, with a Snowflake alert and email on ALERT events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily exceptions, material errors by reporting unit, material-error risk) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_EVENTS inserts simulated source-feed load events into RAW.LIVE_EVENTS, with a Snowflake alert and email on ALERT events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Sign-off & Lineage', icon: '', content: planning },
    { id: 'live', label: 'Live Feed', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional Philippine bank. On-demand snapshots are not live customer operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No reporting-unit observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Philippine Bank Regulatory Reporting" tabs={tabs} />;
}
