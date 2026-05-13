-- ============================================================
-- 04_stream_task.sql
-- Stream, Stored Procedure, Task — SCD Type 1 logic
-- Run AFTER 03_snowpipe.sql
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DEA_REAL_TIME_SCD1.RAW;


-- -----------------------------------------------
-- Create Stream on Raw Table
-- -----------------------------------------------
-- Tracks ALL changes (inserts, updates, deletes)
-- since last Task successfully consumed it
-- Bookmark advances only on successful Task commit

CREATE OR REPLACE STREAM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM
    ON TABLE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW;

-- Verify stream created
SHOW STREAMS;

-- Check stream contents (only unprocessed rows visible)
SELECT * FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM;

-- Check if stream currently has data
SELECT SYSTEM$STREAM_HAS_DATA('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM');


-- -----------------------------------------------
-- Create Stored Procedure (SCD Type 1 Logic)
-- -----------------------------------------------
-- Step 1: Flatten VARIANT JSON from Stream into typed temp table
-- Step 2: MERGE temp table into Transformed Table
--   MATCHED     → UPDATE (overwrite — SCD Type 1)
--   NOT MATCHED → INSERT (new employee)

CREATE OR REPLACE PROCEDURE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_SP()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
try
{
    // Step 1: Flatten JSON_DATA VARIANT into typed columns
    snowflake.execute({sqlText:`
        CREATE OR REPLACE TEMPORARY TABLE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_TEMP AS
        SELECT
            JSON_DATA:employee_id::STRING   AS EMPLOYEE_ID,
            JSON_DATA:employee_name::STRING AS EMPLOYEE_NAME,
            JSON_DATA:department::STRING    AS DEPARTMENT,
            JSON_DATA:designation::STRING   AS DESIGNATION,
            JSON_DATA:salary::INTEGER       AS SALARY,
            JSON_DATA:joining_date::DATE    AS JOINING_DATE,
            JSON_DATA:city::STRING          AS CITY,
            JSON_DATA:state::STRING         AS STATE,
            JSON_DATA:country::STRING       AS COUNTRY
        FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM;
    `});

    // Step 2: SCD Type 1 MERGE into Transformed Table
    snowflake.execute({sqlText:`
        MERGE INTO DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED T
        USING DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_TEMP S
        ON T.EMPLOYEE_ID = S.EMPLOYEE_ID

        WHEN MATCHED THEN
            UPDATE SET
                T.EMPLOYEE_NAME = S.EMPLOYEE_NAME,
                T.DEPARTMENT    = S.DEPARTMENT,
                T.DESIGNATION   = S.DESIGNATION,
                T.SALARY        = S.SALARY,
                T.JOINING_DATE  = S.JOINING_DATE,
                T.CITY          = S.CITY,
                T.STATE         = S.STATE,
                T.COUNTRY       = S.COUNTRY,
                T.UPDATE_DTS    = CURRENT_TIMESTAMP()

        WHEN NOT MATCHED THEN
            INSERT (
                EMPLOYEE_ID,
                EMPLOYEE_NAME,
                DEPARTMENT,
                DESIGNATION,
                SALARY,
                JOINING_DATE,
                CITY,
                STATE,
                COUNTRY,
                INSERT_DTS,
                UPDATE_DTS
            )
            VALUES (
                S.EMPLOYEE_ID,
                S.EMPLOYEE_NAME,
                S.DEPARTMENT,
                S.DESIGNATION,
                S.SALARY,
                S.JOINING_DATE,
                S.CITY,
                S.STATE,
                S.COUNTRY,
                CURRENT_TIMESTAMP(),
                CURRENT_TIMESTAMP()
            );
    `});

    return "Stored Procedure Executed Successfully";
}
catch (err)
{
    result = 'Error: ' + err;
    snowflake.execute({sqlText:`ROLLBACK;`});
    throw result;
}
$$;

-- Test stored procedure manually
-- CALL DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_SP();


-- -----------------------------------------------
-- Create Task
-- -----------------------------------------------
-- Runs every 1 minute
-- WHEN condition: skips execution if stream is empty
-- Saves warehouse compute when no new data arrives

CREATE OR REPLACE TASK DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_STREAM')
AS
CALL DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_SP();

-- Verify task created
SHOW TASKS;


-- -----------------------------------------------
-- Resume / Suspend Task
-- -----------------------------------------------
-- ⚠️ Tasks are SUSPENDED by default after creation
-- Must explicitly RESUME or it will never run

-- Resume
ALTER TASK DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_TASK RESUME;

-- Suspend
-- ALTER TASK DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_SCD1_TASK SUSPEND;

-- Verify state (look for 'started' vs 'suspended')
SHOW TASKS;


-- -----------------------------------------------
-- Task History
-- -----------------------------------------------

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
