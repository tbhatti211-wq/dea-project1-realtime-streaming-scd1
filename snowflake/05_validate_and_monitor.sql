-- ============================================================
-- 05_validate_and_monitor.sql
-- All validation, monitoring, debugging, and teardown queries
-- Run any time during or after testing
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;


-- ============================================================
-- SECTION 1: Pre-Test Checklist
-- Run before firing Postman to confirm everything is live
-- ============================================================

-- Snowpipe running?
-- Expected: {"executionState":"RUNNING","pendingFileCount":0}
SELECT SYSTEM$PIPE_STATUS('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE');

-- Task running?
-- Look for state = 'started' not 'suspended'
SHOW TASKS;

-- Stream exists?
SHOW STREAMS;

-- Stream currently empty before test?
SELECT * FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM;

-- Resume task if suspended
ALTER TASK DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_TASK RESUME;


-- ============================================================
-- SECTION 2: Raw Table Validation
-- ============================================================

-- All records
SELECT * FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW;

-- Total count
SELECT COUNT(*) AS TOTAL_RAW_RECORDS
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW;

-- Extract specific fields from VARIANT JSON
SELECT
    JSON_DATA:employee_id::STRING   AS EMPLOYEE_ID,
    JSON_DATA:employee_name::STRING AS EMPLOYEE_NAME,
    JSON_DATA:salary::INTEGER       AS SALARY,
    JSON_DATA:department::STRING    AS DEPARTMENT
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
ORDER BY JSON_DATA:employee_id;

-- Check for duplicates in raw
-- Expected: duplicates ARE normal here — raw keeps full history
SELECT
    JSON_DATA:employee_id::STRING AS EMPLOYEE_ID,
    COUNT(*) AS RECORD_COUNT
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================================
-- SECTION 3: Stream Validation
-- ============================================================

-- Current unprocessed rows in stream
SELECT * FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM;

-- Does stream have data right now?
SELECT SYSTEM$STREAM_HAS_DATA('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM');

-- Stream metadata breakdown
SELECT
    METADATA$ACTION,
    METADATA$ISUPDATE,
    JSON_DATA:employee_id::STRING AS EMPLOYEE_ID
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM;


-- ============================================================
-- SECTION 4: Transformed Table Validation
-- ============================================================

-- All records latest first
SELECT * FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED
ORDER BY UPDATE_DTS DESC;

-- Total count
-- Should equal number of UNIQUE employees, not total raw rows
SELECT COUNT(*) AS TOTAL_TRANSFORMED_RECORDS
FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED;

-- Check for duplicates in transformed
-- Should always return 0 rows — any result here is a bug
SELECT
    EMPLOYEE_ID,
    COUNT(*) AS RECORD_COUNT
FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED
GROUP BY EMPLOYEE_ID
HAVING COUNT(*) > 1;

-- Raw vs Transformed row count comparison (SCD1 proof)
SELECT 'RAW' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
UNION ALL
SELECT 'TRANSFORMED', COUNT(*)
FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED;


-- ============================================================
-- SECTION 5: SCD Type 1 Verification
-- ============================================================

-- Verify specific employee shows latest values only
SELECT
    EMPLOYEE_ID,
    EMPLOYEE_NAME,
    DESIGNATION,
    SALARY,
    INSERT_DTS,
    UPDATE_DTS
FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED
WHERE EMPLOYEE_ID = 'E001';

-- Show full raw history for same employee
-- Raw will have multiple rows, transformed will have one
SELECT
    JSON_DATA:employee_id::STRING   AS EMPLOYEE_ID,
    JSON_DATA:salary::INTEGER       AS SALARY,
    JSON_DATA:designation::STRING   AS DESIGNATION
FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
WHERE JSON_DATA:employee_id::STRING = 'E001';


-- ============================================================
-- SECTION 6: Snowpipe Load History
-- ============================================================

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


-- ============================================================
-- SECTION 7: Task History
-- ============================================================

-- All runs most recent first
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'EMPLOYEE_SCD1_TASK'
    )
)
ORDER BY SCHEDULED_TIME DESC;

-- Failed runs only
SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'EMPLOYEE_SCD1_TASK'
    )
)
WHERE STATE = 'FAILED'
ORDER BY SCHEDULED_TIME DESC;


-- ============================================================
-- SECTION 8: Ad-hoc Cleanup (used during testing)
-- ============================================================

-- Delete specific record from raw
DELETE FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
WHERE JSON_DATA:employee_id::STRING = 'E007'
AND JSON_DATA:salary::INTEGER = 120000;

-- Delete specific records from transformed
DELETE FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED
WHERE EMPLOYEE_ID IN ('E013', 'E014', 'E015');

-- Full reset — wipes all data (use carefully)
-- TRUNCATE TABLE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW;
-- TRUNCATE TABLE DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED;


-- ============================================================
-- SECTION 9: Teardown (Module 14)
-- ============================================================

-- Suspend Task
ALTER TASK DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_TASK SUSPEND;

-- Pause Snowpipe
ALTER PIPE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE
    SET PIPE_EXECUTION_PAUSED = TRUE;

-- Verify both stopped
SHOW TASKS;
SELECT SYSTEM$PIPE_STATUS('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_PIPE');

-- Full teardown — drops everything (uncomment when ready)
-- DROP DATABASE DEA_REAL_TIME_SCD1;
