-- Storage Integration
CREATE OR REPLACE STORAGE INTEGRATION DEA_REAL_TIME_SCD1_INT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '<your-role-arn>'
    STORAGE_ALLOWED_LOCATIONS = ('s3://your-bucket/');

-- File Format
CREATE OR REPLACE FILE FORMAT your_file_format
    TYPE = 'JSON';

-- External Stage
CREATE OR REPLACE STAGE your_stage
    URL = 's3://your-data-bucket/'
    STORAGE_INTEGRATION = DEA_REAL_TIME_SCD1_INT
    FILE_FORMAT = your_file_format;
