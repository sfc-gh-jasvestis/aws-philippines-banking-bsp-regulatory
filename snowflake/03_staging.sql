-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.UNIT_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.UNIT_DAILY observation
    LEFT JOIN RAW.REPORTING_UNITS unit ON unit.ID = observation.ENTITY_ID
    WHERE unit.ID IS NULL OR observation.CHECK_COUNT < 0
       OR observation.RECORD_COUNT < 0 OR observation.BALANCE_PHP < 0
       OR observation.MATERIAL_ERROR_COUNT < 0 OR observation.MATERIAL_ERROR_COUNT > observation.EXCEPTION_COUNT
       OR observation.ITEMS_ESCALATED > observation.MATERIAL_ERROR_COUNT
       OR observation.SIGNOFF_COMPLETED > observation.SIGNOFF_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
