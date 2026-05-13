CREATE OR REPLACE TABLE raw_employee_events (
  src_filename STRING,
  src_row_number NUMBER,
  employee_id STRING,
  first_name STRING,
  last_name STRING,
  email STRING,
  department STRING,
  job_title STRING,
  salary NUMBER(12,2),
  ingested_at TIMESTAMP_NTZ,
  validation_status STRING,
  validation_message STRING,
  load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE dim_employee_scd1 (
  employee_id STRING PRIMARY KEY,
  first_name STRING,
  last_name STRING,
  email STRING,
  department STRING,
  job_title STRING,
  salary NUMBER(12,2),
  source_ingested_at TIMESTAMP_NTZ,
  updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
