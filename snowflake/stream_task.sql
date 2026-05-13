CREATE OR REPLACE STREAM raw_employee_events_stream
  ON TABLE raw_employee_events
  APPEND_ONLY = TRUE;

CREATE OR REPLACE PROCEDURE sp_merge_employee_scd1()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  MERGE INTO dim_employee_scd1 AS tgt
  USING (
    SELECT
      employee_id,
      first_name,
      last_name,
      email,
      department,
      job_title,
      salary,
      ingested_at,
      ROW_NUMBER() OVER (
        PARTITION BY employee_id
        ORDER BY ingested_at DESC, load_timestamp DESC
      ) AS row_num
    FROM raw_employee_events_stream
    WHERE validation_status = 'valid'
  ) AS src
  ON tgt.employee_id = src.employee_id
  WHEN MATCHED AND src.row_num = 1 THEN
    UPDATE SET
      first_name = src.first_name,
      last_name = src.last_name,
      email = src.email,
      department = src.department,
      job_title = src.job_title,
      salary = src.salary,
      source_ingested_at = src.ingested_at,
      updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED AND src.row_num = 1 THEN
    INSERT (
      employee_id,
      first_name,
      last_name,
      email,
      department,
      job_title,
      salary,
      source_ingested_at,
      updated_at
    )
    VALUES (
      src.employee_id,
      src.first_name,
      src.last_name,
      src.email,
      src.department,
      src.job_title,
      src.salary,
      src.ingested_at,
      CURRENT_TIMESTAMP()
    );

  RETURN 'SCD1 merge completed';
END;
$$;

CREATE OR REPLACE TASK task_merge_employee_scd1
  -- Replace with your compute warehouse, e.g. WAREHOUSE = COMPUTE_WH.
  WAREHOUSE = <YOUR_WAREHOUSE>
  SCHEDULE = 'USING CRON * * * * * UTC'
  WHEN SYSTEM$STREAM_HAS_DATA('raw_employee_events_stream')
AS
CALL sp_merge_employee_scd1();
