-- ============================================================================
-- 08_native_events.sql - Snowflake-only build: live source-feed load events without AWS.
-- Creates RAW.LIVE_EVENTS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_EVENTS(N), which inserts synthetic
-- source-system feed load events (balance loaded, failed validation checks) with
-- the same value ranges and
-- ~10% ALERT rate as aws/publish_events.py. Rows are inserted directly; this
-- simulates an event feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_EVENTS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_EVENTS (
  UNIT_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, SOURCE_SYSTEM VARCHAR, BALANCE_PHP FLOAT,
  FAILED_CHECKS NUMBER, STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_EVENTS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_EVENTS (UNIT_ID, EVENT_TS, SOURCE_SYSTEM, BALANCE_PHP, FAILED_CHECKS, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'RU-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS UNIT_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_ALERT,
             UNIFORM(0, 4, RANDOM()) AS CH,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the alert offset is added outside it.
    SELECT UNIT_ID, TS,
           DECODE(CH, 0, 'Loan origination system', 1, 'Core deposit system', 2, 'Risk-weighted asset engine', 3, 'Treasury and ALM system', 'General ledger'),
           ROUND(IFF(IS_ALERT, 90000000, 25000000) * EXP(NORMAL(0, 0.6, RANDOM())), 2),
           GREATEST(0, ROUND(IFF(IS_ALERT, 5, 0) + NORMAL(0, 0.8, RANDOM()))),
           IFF(IS_ALERT, 'ALERT', 'OK'), TS, 'APP.SIMULATE_EVENTS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_EVENTS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_EVENTS(5);
