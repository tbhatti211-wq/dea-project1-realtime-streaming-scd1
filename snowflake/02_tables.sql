-- ============================================================
-- 02_tables.sql
-- Raw Table and Transformed Table DDL
-- Run AFTER 01_setup.sql
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA DEA_REAL_TIME_SCD1.RAW;


-- -----------------------------------------------
-- Raw Table (VARIANT — schema on read)
-- -----------------------------------------------
-- Stores JSON exactly as received from S3
-- Append-only — never updated or deleted
-- Full history of every record ever received

CREATE OR REPLACE TABLE DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW
(
    JSON_DATA VARIANT
);

-- Verify
SELECT * FROM DEA_REAL_TIME_SCD1.RAW.EMPLOYEE_RAW LIMIT 10;


-- -----------------------------------------------
-- Transformed Table (typed columns — SCD Type 1)
-- -----------------------------------------------
-- One row per employee — always current state
-- Updated via MERGE in stored procedure
-- No history kept — that is the definition of SCD Type 1

CREATE OR REPLACE TABLE DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED
(
    EMPLOYEE_ID     STRING,
    EMPLOYEE_NAME   STRING,
    DEPARTMENT      STRING,
    DESIGNATION     STRING,
    SALARY          INTEGER,
    JOINING_DATE    DATE,
    CITY            STRING,
    STATE           STRING,
    COUNTRY         STRING,
    INSERT_DTS      TIMESTAMP(6),
    UPDATE_DTS      TIMESTAMP(6)
);

-- Verify
SELECT * FROM DEA_REAL_TIME_SCD1.TRANSFORMED.EMPLOYEE_TRANSFORMED LIMIT 10;
