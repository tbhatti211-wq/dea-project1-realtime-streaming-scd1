import json
import os
from datetime import datetime
from typing import Any, Dict, List

import boto3

STREAM_NAME = os.environ.get("STREAM_NAME", "employee-data-stream")
ERROR_BUCKET_NAME = os.environ.get("ERROR_BUCKET_NAME", "employee-error-bucket")

s3_client = boto3.client("s3")
kinesis_client = boto3.client("kinesis")


def _build_get_response() -> Dict[str, Any]:
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Real-time employee event ingestion API",
                "status": "active",
                "version": "1.0",
                "description": "Submit employee records with POST for validation and streaming.",
                "endpoints": {
                    "GET": "Returns service status and usage information",
                    "POST": "Accepts one or more employee records for processing",
                },
                "request_format": {
                    "body": [
                        {
                            "employee_id": "123",
                            "first_name": "Jane",
                            "last_name": "Doe",
                            "email": "jane.doe@example.com",
                            "department": "Engineering",
                            "job_title": "Data Engineer",
                            "salary": 95000,
                        }
                    ]
                },
            }
        ),
        "headers": {"Content-Type": "application/json"},
    }


def _normalize_records(event: Dict[str, Any]) -> List[Dict[str, Any]]:
    body = event.get("body", "[]")
    if isinstance(body, str):
        data = json.loads(body or "[]")
    else:
        data = body

    if isinstance(data, dict):
        data = [data]

    if not isinstance(data, list):
        raise ValueError("Request body must be a JSON object or array of objects")

    for record in data:
        if not isinstance(record, dict):
            raise ValueError("Each record must be a JSON object")

    return data


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    http_method = event.get("httpMethod", "")

    if http_method == "GET":
        return _build_get_response()

    if http_method and http_method != "POST":
        return {
            "statusCode": 405,
            "body": json.dumps({"message": "Method not allowed. Use GET or POST."}),
            "headers": {"Content-Type": "application/json"},
        }

    try:
        records = _normalize_records(event)

        success_count = 0
        error_count = 0

        for record in records:
            timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S%f")

            if "employee_id" not in record or record["employee_id"] in [None, ""]:
                object_key = f"errors/error_{timestamp}.json"
                s3_client.put_object(
                    Bucket=ERROR_BUCKET_NAME,
                    Key=object_key,
                    Body=json.dumps(record).encode("utf-8"),
                    ContentType="application/json",
                )
                error_count += 1
            else:
                kinesis_client.put_record(
                    StreamName=STREAM_NAME,
                    Data=json.dumps(record),
                    PartitionKey=str(record["employee_id"]),
                )
                success_count += 1

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Data processing completed",
                    "success_records": success_count,
                    "error_records": error_count,
                    "stream_name": STREAM_NAME,
                    "error_bucket": ERROR_BUCKET_NAME,
                }
            ),
            "headers": {"Content-Type": "application/json"},
        }

    except ValueError as exc:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": str(exc)}),
            "headers": {"Content-Type": "application/json"},
        }
    except Exception as exc:
        print(f"Error processing event: {exc}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": f"Error processing event: {exc}"}),
            "headers": {"Content-Type": "application/json"},
        }
