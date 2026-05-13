-- ============================================================
-- 03_snowpipe.sql
-- Snowpipe setup for auto-ingest from S3 via SQS
-- Run AFTER 02_tables.sql
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DEA_REAL_TIME_SCD1.RAW;


-- -----------------------------------------------
-- Create Snowpipe
-- -----------------------------------------------
-- AUTO_INGEST = TRUE means Snowpipe listens to SQS
-- Automatically runs COPY INTO when new file lands in S3

CREATE OR REPLACE PIPE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE
    AUTO_INGEST = TRUE AS
    COPY INTO DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
    FROM @DEA_REAL_TIME_SCD1.RAW.DEA_REAL_TIME_SCD1_STAGE
    FILE_FORMAT = (TYPE = 'JSON');


-- -----------------------------------------------
-- Verify Pipe Created
-- -----------------------------------------------

SHOW PIPES;


-- -----------------------------------------------
-- Get SQS ARN for S3 Event Notification
-- -----------------------------------------------
-- IMPORTANT: Run this and copy the notification_channel value
-- Then go to:
--   AWS Console → S3 → your data bucket
--   → Properties → Event Notifications → Create notification
--   → Event type: s3:ObjectCreated:* (PUT)
--   → Destination: SQS → paste notification_channel ARN here

DESC PIPE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE;


-- -----------------------------------------------
-- Check Snowpipe Status
-- -----------------------------------------------
-- Expected: {"executionState":"RUNNING","pendingFileCount":0}
-- pendingFileCount > 0 means files are queued waiting to load

SELECT SYSTEM$PIPE_STATUS('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE');


-- -----------------------------------------------
-- Check Load History (audit trail)
-- -----------------------------------------------
-- Shows every file Snowpipe has loaded
-- Snowpipe uses this to prevent loading the same file twice

SELECT
    FILE_NAME,
    STATUS,
    ROW_COUNT,
    FIRST_ERROR_MESSAGE,
    LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'EMPLOYEE_RAW',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;


-- -----------------------------------------------
-- Pause / Resume Pipe
-- -----------------------------------------------

-- Pause (stops auto-ingest — use during teardown)
ALTER PIPE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE
    SET PIPE_EXECUTION_PAUSED = TRUE;

-- Resume
ALTER PIPE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE
    SET PIPE_EXECUTION_PAUSED = FALSE;

-- Verify status after pause/resume
SELECT SYSTEM$PIPE_STATUS('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE');
