import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, Tuple

import boto3

s3_client = boto3.client("s3")

TARGET_BUCKET = os.environ.get("TARGET_BUCKET", "")
RAW_PREFIX = os.environ.get("RAW_PREFIX", "employee-events/raw")
REJECTED_PREFIX = os.environ.get("REJECTED_PREFIX", "employee-events/rejected")
REQUIRED_FIELDS = (
    "employee_id",
    "first_name",
    "last_name",
    "email",
    "department",
    "job_title",
    "salary",
)


def _parse_body(event: Dict[str, Any]) -> Tuple[Dict[str, Any], str]:
    body = event.get("body", {})
    if isinstance(body, str):
        body = json.loads(body or "{}")
    if not isinstance(body, dict):
        raise ValueError("Request body must be a JSON object")

    request_id = (
        event.get("requestContext", {}).get("requestId")
        or event.get("headers", {}).get("x-request-id")
        or f"manual-{int(datetime.now(tz=timezone.utc).timestamp() * 1000)}"
    )
    return body, request_id


def _validate(payload: Dict[str, Any]) -> Tuple[bool, str]:
    missing = [field for field in REQUIRED_FIELDS if payload.get(field) in (None, "")]
    if missing:
        return False, f"Missing required field(s): {', '.join(missing)}"

    if "@" not in str(payload.get("email", "")):
        return False, "Invalid email format"

    try:
        salary = float(payload["salary"])
        if salary < 0:
            return False, "Salary must be non-negative"
    except (TypeError, ValueError):
        return False, "Salary must be numeric"

    return True, "valid"


def _build_key(prefix: str, employee_id: Any, request_id: str) -> str:
    now = datetime.now(tz=timezone.utc)
    return (
        f"{prefix}/year={now:%Y}/month={now:%m}/day={now:%d}/"
        f"employee_id={employee_id}/{request_id}.json"
    )


def _put_record(bucket: str, key: str, payload: Dict[str, Any], metadata: Dict[str, str]) -> None:
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(payload, default=str).encode("utf-8"),
        ContentType="application/json",
        Metadata=metadata,
    )


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    if not TARGET_BUCKET:
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "TARGET_BUCKET environment variable is required"}),
        }

    try:
        payload, request_id = _parse_body(event)
    except (json.JSONDecodeError, ValueError) as exc:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": str(exc)}),
        }

    is_valid, validation_message = _validate(payload)
    routing_prefix = RAW_PREFIX if is_valid else REJECTED_PREFIX
    object_key = _build_key(routing_prefix, payload.get("employee_id", "unknown"), request_id)

    enriched_payload = {
        **payload,
        "ingested_at": datetime.now(tz=timezone.utc).isoformat(),
        "validation_status": "valid" if is_valid else "invalid",
        "validation_message": validation_message,
    }

    _put_record(
        bucket=TARGET_BUCKET,
        key=object_key,
        payload=enriched_payload,
        metadata={
            "validation_status": enriched_payload["validation_status"],
            "request_id": request_id,
        },
    )

    return {
        "statusCode": 200 if is_valid else 400,
        "body": json.dumps(
            {
                "message": "Event accepted" if is_valid else "Event rejected",
                "validation_message": validation_message,
                "bucket": TARGET_BUCKET,
                "key": object_key,
            }
        ),
    }
