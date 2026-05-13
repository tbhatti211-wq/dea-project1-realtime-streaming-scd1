# ⚡ Real-Time Streaming Pipeline with SCD Type 1
> **An end-to-end data engineering project** building a near real-time employee data pipeline — from REST API ingestion through AWS streaming infrastructure to Snowflake transformation with SCD Type 1 logic.

[![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python)](https://python.org)
[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20Kinesis%20%7C%20Firehose%20%7C%20S3-orange?logo=amazonaws)](https://aws.amazon.com)
[![Snowflake](https://img.shields.io/badge/Snowflake-Snowpipe%20%7C%20Streams%20%7C%20Tasks-29B5E8?logo=snowflake)](https://snowflake.com)
[![Status](https://img.shields.io/badge/Status-Complete-brightgreen)]()

---

## 🧭 Project Overview

Modern data platforms need to move data from source to insight in minutes, not hours. This project builds a production-pattern streaming pipeline that ingests employee records via REST API, validates and routes them in real-time, delivers them to a Snowflake data warehouse, and applies incremental transformation using SCD Type 1 logic — all with zero manual intervention after the initial trigger.

**Key questions this project answers:**
- How do you build an event-driven pipeline that reacts to data arrival rather than running on a fixed schedule?
- How do you separate raw ingestion from transformation to enable reprocessing without data loss?
- How do you handle invalid data gracefully without blocking the main pipeline?
- How do you apply SCD Type 1 incrementally — processing only new and changed rows, not full table scans?

---

## 🗂️ Project Structure

```
dea-project1-realtime-streaming-scd1/
│
├── lambda/
│   └── lambda_function.py          # Validation + routing logic (Python)
│
├── snowflake/
│   ├── setup.sql                   # Storage integration, stage, file format
│   ├── tables.sql                  # Raw + Transformed table DDL
│   ├── snowpipe.sql                # Pipe creation with AUTO_INGEST
│   └── stream_task.sql             # Stream, Task, Stored Procedure (MERGE)
│
├── postman/
│   └── test_payloads.json          # Full load, incremental, invalid test cases
│
└── README.md
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Ingestion | AWS API Gateway, AWS Lambda (Python) |
| Streaming | Amazon Kinesis Data Streams, Kinesis Firehose |
| Storage | Amazon S3 (data bucket + error bucket) |
| Messaging | Amazon SQS |
| Auto-Ingest | Snowflake Snowpipe |
| Transformation | Snowflake Streams, Tasks, Stored Procedures |
| Auth | AWS IAM, Snowflake Storage Integration |
| Testing | Postman |
| Monitoring | AWS CloudWatch |

---

## 🏗️ Architecture
<img width="1234" height="500" alt="image" src="https://github.com/user-attachments/assets/ade716b4-fbad-4f7d-8a39-80b811399d7c" />

```
> End-to-end event-driven pipeline from REST API ingestion 
> through AWS streaming infrastructure to Snowflake transformation.
```

---

## 📦 Pipeline Stages

### Stage 1 — Ingestion & Validation
- Postman sends HTTP POST with a JSON array of employee records to API Gateway
- Lambda validates each record — checks for required `employee_id` field
  - ✅ Valid → forwarded to Kinesis Data Stream
  - ❌ Invalid → written directly to S3 Error Bucket (isolated, quarantined)
- Lambda returns response with `success_records` and `error_records` count

### Stage 2 — Streaming & Delivery
- **Kinesis Data Stream** buffers records with 24-hour replay capability
- **Firehose** consumes the stream, batches records, flushes to S3 on buffer interval
- Files land in S3 partitioned by date/hour: `s3://bucket/YYYY/MM/DD/HH/filename`
- Two buckets maintained: data bucket (clean path) and error bucket (quarantine)

### Stage 3 — Auto-Load into Snowflake
- S3 PUT event triggers S3 Event Notification → SQS message
- Snowpipe listens to SQS queue, automatically executes COPY INTO Raw Table
- Raw Table is **append-only** — every version of every record preserved permanently
- Snowpipe tracks load history — same file never loaded twice

### Stage 4 — Incremental Transformation (SCD Type 1)
- Snowflake Stream tracks only new/changed rows since last Task run (bookmark-based offset)
- Task checks `SYSTEM$STREAM_HAS_DATA` before executing — skips if empty (cost control)
- Stored Procedure executes MERGE:
  - New employee → `WHEN NOT MATCHED` → INSERT
  - Updated employee → `WHEN MATCHED` → UPDATE (overwrite, no history = Type 1)
- Transformed Table always holds **one current row per employee**

---

## 🧪 Test Scenarios

| Scenario | Input | Expected Output | Result |
|----------|-------|-----------------|--------|
| Full Load | 7 valid employee records | All 7 rows in Raw + Transformed | ✅ Pass |
| Incremental / SCD1 | E001 with updated salary (95k → 105k) | Raw: 2 rows for E001 / Transformed: 1 row (latest only) | ✅ Pass |
| Invalid Data | Record with empty `employee_id` | Routed to S3 error bucket, not in Snowflake | ✅ Pass |
| Duplicate POST | Same 7 records sent twice | Transformed stays at 7 rows (idempotent MERGE) | ✅ Pass |

---

## ⏱️ Observed Latency

| Segment | Latency |
|---------|---------|
| API Gateway → Kinesis | ~milliseconds |
| Kinesis → S3 (Firehose flush) | ~60 seconds (buffer interval) |
| S3 → Raw Table (Snowpipe) | ~30–60 seconds |
| Raw Table → Transformed (Task) | ~1–5 minutes (task schedule) |
| **End-to-end total** | **~3–5 minutes** |

> **Near real-time, not sub-second.** True sub-second latency would require bypassing Firehose and connecting Kinesis directly to Snowflake via a Kafka Connector — adding operational complexity not justified for this use case.

---

## 🔑 Key Design Decisions

**Why Kinesis Data Stream + Firehose instead of Lambda → Firehose directly?**
KDS enables multiple downstream consumers (analytics, alerting, ML model) without rewiring the pipeline. It also provides 24-hour replay capability — if Firehose goes down, records are not lost. Lambda → Firehose directly would work at this scale but sacrifices flexibility.

**Why two S3 buckets?**
Separation of concerns. The data bucket is the clean ingestion path watched by Snowpipe. The error bucket is isolated — invalid records land there for ops visibility and manual reprocessing without polluting the main pipeline.

**Why SCD Type 1 instead of Type 2?**
The use case requires current state only — no historical tracking needed. Type 1 is simpler, more performant, and appropriate when the only business question is *"what is the current value?"* Type 2 would be the right choice if stakeholders needed *"what was the value on a given date?"*

**Why keep the Raw Table append-only?**
The Raw Table is the reprocessing safety net. If transformation logic has a bug, the Transformed Table can be truncated and rebuilt from Raw at any time — no need to re-ingest from the source system.

**Why External Stage instead of Internal?**
Data originates in AWS S3 (outside Snowflake), so Snowflake needs an authenticated pointer to reach it. The External Stage + Storage Integration + IAM trust policy handshake enables Snowflake to securely read from S3 without embedding AWS credentials.

---

## 🐛 Bug Caught During Testing

**Issue:** Duplicate records appearing in Transformed Table when the same payload was sent twice via Postman.

**Root Cause:** MERGE statement was missing `METADATA$ACTION` and `METADATA$ISUPDATE` filter conditions. Without them, the DELETE rows emitted by the Stream for update operations also triggered MERGE conditions — causing incorrect duplicate inserts alongside the intended updates.

**Diagnosis:** Compared row counts between Raw Table (expected duplicates) and Transformed Table (should be deduplicated). Row counts matched Raw instead of staying at 7 — confirmed MERGE logic was treating Stream DELETE rows as new inserts.

**Fix:** Pre-filter the Stream in the USING clause to exclude DELETE rows before MERGE executes:

```sql
MERGE INTO TRANSFORMED_TABLE T
USING (
    SELECT * FROM RAW_STREAM
    WHERE METADATA$ACTION = 'INSERT'  -- exclude DELETE rows entirely
) S
ON T.EMPLOYEE_ID = S.EMPLOYEE_ID
WHEN MATCHED AND S.METADATA$ISUPDATE = TRUE
    THEN UPDATE SET
        T.SALARY     = S.SALARY,
        T.UPDATE_DTS = CURRENT_TIMESTAMP()
        -- all columns...
WHEN NOT MATCHED
    THEN INSERT (EMPLOYEE_ID, EMPLOYEE_NAME, ...)
    VALUES (S.EMPLOYEE_ID, S.EMPLOYEE_NAME, ...);
```

---

## 🚀 What I'd Improve in Production

- **Environment variables** for all resource names — no hardcoded strings in Lambda
- **CloudWatch alarms** on Lambda error rate + Firehose delivery failures + dead-letter SQS queue depth
- **Idempotency key** (MD5 hash of record content) at Lambda level to deduplicate before Kinesis
- **Firehose buffer interval 300s** in production — fewer S3 files, lower cost, acceptable latency
- **SCD Type 2** if business requires full historical change tracking
- **Snowflake Time Travel** queries for auditing exact column-level changes over time
- **Separate AWS accounts** for dev / staging / production environments

---

## 🏃 Getting Started

### Prerequisites
- AWS account (free tier sufficient for testing)
- Snowflake account (30-day free trial)
- Postman

### Setup Order
```
1. AWS S3        → create data bucket + error bucket
2. AWS IAM       → create role with Kinesis + S3 + Lambda policies
3. AWS Kinesis   → create Data Stream + Firehose delivery stream
4. AWS Lambda    → deploy lambda_function.py, set environment variables
5. AWS API Gateway → create REST API, POST method → Lambda integration
6. Snowflake     → run setup.sql → tables.sql → snowpipe.sql → stream_task.sql
7. AWS S3        → add event notification pointing to Snowpipe SQS ARN
8. Postman       → import test_payloads.json → fire requests
```

### Verify End-to-End
```sql
-- check raw table received records
SELECT COUNT(*) FROM RAW_TABLE;

-- check transformed table (one row per employee)
SELECT COUNT(*) FROM TRANSFORMED_TABLE;

-- verify SCD1 — E001 should show latest values only
SELECT * FROM TRANSFORMED_TABLE WHERE EMPLOYEE_ID = 'E001';

-- check Snowpipe load history
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'RAW_TABLE',
    START_TIME => DATEADD('hour', -24, CURRENT_TIMESTAMP())
));
```

---

## 📈 Key Findings

- **End-to-end latency ~3–5 minutes** — primary bottleneck is Firehose buffer interval (60s in testing)
- **Snowpipe auto-ingest via SQS** eliminated polling lag — data loads within 60 seconds of S3 file arrival
- **Stream + Task pattern** reduced transformation compute to only new/changed rows — scales efficiently as Raw Table grows to millions of rows
- **Two-layer architecture** (Raw + Transformed) proved critical — enabled clean reprocessing after MERGE bug was identified and fixed

---

## 🧑‍💻 About This Project

This project was built as part of the Data Engineering Academy curriculum to demonstrate end-to-end pipeline construction with production-pattern design:
- **Event-driven architecture** — every component reacts to the previous step, nothing polled on fixed schedules
- **Data quality thinking** — error routing, invalid record quarantine, and duplicate detection built in from day one
- **Incremental processing** — Stream-based CDC ensures only new and changed data is processed, not full table scans
- **Debugging under pressure** — identified and fixed a real MERGE idempotency bug during testing

**Author:** Talib Hussain
**GitHub:** [github.com/kibraahsan](https://github.com/kibraahsan)
**LinkedIn:** [linkedin.com/in/talhussain](https://linkedin.com/in/talhussain)

---

## 📄 License
MIT License — analysis code free to use and adapt.

---
*Last updated: May 2026*
