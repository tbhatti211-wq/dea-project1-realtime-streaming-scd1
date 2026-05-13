-- Raw Table
CREATE OR REPLACE TABLE raw_table (
    employee_id     VARCHAR,
    employee_name   VARCHAR,
    department      VARCHAR,
    designation     VARCHAR,
    salary          NUMBER,
    joining_date    DATE,
    city            VARCHAR,
    state           VARCHAR,
    country         VARCHAR,
    insert_dts      TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Transformed Table
CREATE OR REPLACE TABLE transformed_table (
    employee_id     VARCHAR,
    employee_name   VARCHAR,
    department      VARCHAR,
    designation     VARCHAR,
    salary          NUMBER,
    joining_date    DATE,
    city            VARCHAR,
    state           VARCHAR,
    country         VARCHAR,
    insert_dts      TIMESTAMP,
    update_dts      TIMESTAMP
);
