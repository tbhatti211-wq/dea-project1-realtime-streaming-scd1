CREATE OR REPLACE PIPE employee_events_pipe
  AUTO_INGEST = TRUE
AS
COPY INTO raw_employee_events (
  src_filename,
  src_row_number,
  employee_id,
  first_name,
  last_name,
  email,
  department,
  job_title,
  salary,
  ingested_at,
  validation_status,
  validation_message
)
FROM (
  SELECT
    METADATA$FILENAME,
    METADATA$FILE_ROW_NUMBER,
    $1:employee_id::STRING,
    $1:first_name::STRING,
    $1:last_name::STRING,
    $1:email::STRING,
    $1:department::STRING,
    $1:job_title::STRING,
    $1:salary::NUMBER(12,2),
    $1:ingested_at::TIMESTAMP_NTZ,
    $1:validation_status::STRING,
    $1:validation_message::STRING
  FROM @employee_events_stage
)
ON_ERROR = 'CONTINUE';
