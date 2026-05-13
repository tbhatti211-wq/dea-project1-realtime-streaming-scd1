sql-- ============================================================
-- 01_setup.sql
-- Database, Schema, Storage Integration, External Stage
-- Run this FIRST
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Create Database
CREATE OR REPLACE DATABASE DEA_REAL_TIME_SCD1;
USE DATABASE DEA_REAL_TIME_SCD1;

-- Create Schemas
CREATE OR REPLACE SCHEMA RAW;
CREATE OR REPLACE SCHEMA TRANSFORMED;


-- -----------------------------------------------
-- Storage Integration (Snowflake → AWS S3)
-- -----------------------------------------------

CREATE OR REPLACE STORAGE INTEGRATION DEA_REAL_TIME_SCD1_INT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/<YOUR_ROLE_NAME>'
    STORAGE_ALLOWED_LOCATIONS = ('s3://<YOUR_BUCKET_NAME>');

-- Verify it exists
SHOW INTEGRATIONS;

-- Run DESC and copy two values into AWS IAM trust policy:
--   STORAGE_AWS_IAM_USER_ARN  → paste as Principal
--   STORAGE_AWS_EXTERNAL_ID  → paste as sts:ExternalId condition
DESC INTEGRATION DEA_REAL_TIME_SCD1_INT;


-- -----------------------------------------------
-- External Stage (pointer to S3)
-- -----------------------------------------------

CREATE OR REPLACE STAGE DEA_REAL_TIME_SCD1.RAW.DEA_REAL_TIME_SCD1_STAGE
    STORAGE_INTEGRATION = DEA_REAL_TIME_SCD1_INT
    URL = 's3://<YOUR_BUCKET_NAME>';

-- Test: lists files currently in your S3 bucket
ls @DEA_REAL_TIME_SCD1.RAW.DEA_REAL_TIME_SCD1_STAGE;
