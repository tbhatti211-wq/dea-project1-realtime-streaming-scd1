# dea-project1-realtime-streaming-scd1

An event-driven, near real-time data pipeline that ingests employee records via REST API, validates and routes them through AWS streaming infrastructure, auto-loads into Snowflake, and applies SCD Type 1 transformation logic using Snowflake-native Streams and Tasks.

## Repository structure

```text
dea-project1-realtime-streaming-scd1/
├── lambda/
│   └── lambda_function.py
├── snowflake/
│   ├── setup.sql
│   ├── tables.sql
│   ├── snowpipe.sql
│   └── stream_task.sql
├── postman/
│   └── test_payloads.json
└── README.md
```

## What is included

- `lambda/lambda_function.py`: Validates incoming employee events, enriches them with ingestion metadata, and writes valid/invalid records to separate S3 prefixes.
- `snowflake/setup.sql`: Creates storage integration, JSON file format, and external stage for the raw S3 prefix.
- `snowflake/tables.sql`: Creates raw landing and SCD1 dimension tables.
- `snowflake/snowpipe.sql`: Creates Snowpipe to auto-ingest staged JSON data into the raw table.
- `snowflake/stream_task.sql`: Creates stream + merge procedure + scheduled task for SCD Type 1 updates.
- `postman/test_payloads.json`: Three test scenarios (new record, update record, invalid record).

## Execution order in Snowflake

1. Run `snowflake/setup.sql`
2. Run `snowflake/tables.sql`
3. Run `snowflake/snowpipe.sql`
4. Run `snowflake/stream_task.sql`

Update placeholders (`<AWS_IAM_ROLE_ARN>`, `<YOUR_BUCKET>`, `<YOUR_WAREHOUSE>`) before running in your environment.
