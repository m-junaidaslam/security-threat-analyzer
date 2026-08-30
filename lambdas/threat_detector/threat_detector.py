import base64
import binascii
import ipaddress
import json
import os
import time
import uuid

import boto3

from datetime import datetime

dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")

alerts_table = dynamodb.Table(
    os.environ["THREAT_ALERTS_TABLE"]
)

login_failure_counters_table = dynamodb.Table(
    os.environ["LOGIN_FAILURE_COUNTERS_TABLE"]
)

VALID_EVENT_TYPES = {
    "LOGIN_SUCCESS",
    "LOGIN_FAILED",
    "API_REQUEST",
    "FILE_DOWNLOAD",
    "LOGOUT",
    "PRIVILEGE_ESCALATION",
    "ACCOUNT_LOCKED",
}


def to_epoch(timestamp_string):

    parsed_timestamp = datetime.fromisoformat(
        timestamp_string.replace("Z", "+00:00")
    )

    if parsed_timestamp.tzinfo is None:
        raise ValueError("Timestamp must include a timezone")

    return int(parsed_timestamp.timestamp())


def publish_alert_metric(severity):

    cloudwatch.put_metric_data(
        Namespace="ThreatAnalyzer",
        MetricData=[
            {
                "MetricName": "ThreatAlerts",
                "Value": 1,
                "Unit": "Count",
                "Dimensions": [
                    {
                        "Name": "Severity",
                        "Value": severity
                    }
                ]
            }
        ]
    )


def create_alert(
    event_type,
    username,
    source_ip,
    severity,
    timestamp
):

    alerts_table.put_item(
        Item={
            "alert_id": str(uuid.uuid4()),
            "event_type": event_type,
            "username": username,
            "source_ip": source_ip,
            "severity": severity,
            "timestamp": timestamp,
            "event_timestamp": to_epoch(timestamp),
            "expires_at": int(time.time()) + (30 * 24 * 3600)
        }
    )
    publish_alert_metric(severity)

    print(
        f"[{severity}] "
        f"{event_type} "
        f"user={username}"
    )


def increment_failed_login(username):

    response = login_failure_counters_table.update_item(
        Key={
            "username": username
        },
        UpdateExpression=(
            "ADD failed_login_count :increment "
            "SET expires_at = :expires_at"
        ),
        ExpressionAttributeValues={
            ":increment": 1,
            ":expires_at": int(time.time()) + 3600
        },
        ReturnValues="UPDATED_NEW"
    )

    return int(
        response["Attributes"]["failed_login_count"]
    )


def validate_security_event(security_event):

    if not isinstance(security_event, dict):
        raise ValueError("Event must be a JSON object")

    event_type = security_event.get("event_type")
    username = security_event.get("username")
    source_ip = security_event.get("source_ip")
    timestamp = security_event.get("timestamp")

    if event_type not in VALID_EVENT_TYPES:
        raise ValueError("Unsupported event type")

    if not isinstance(username, str) or not 1 <= len(username) <= 128:
        raise ValueError("Invalid username")

    if not isinstance(source_ip, str):
        raise ValueError("Invalid source IP")

    try:
        ipaddress.ip_address(source_ip)
    except ValueError as exc:
        raise ValueError("Invalid source IP") from exc

    if not isinstance(timestamp, str):
        raise ValueError("Invalid timestamp")

    to_epoch(timestamp)


def decode_security_event(record):

    payload = base64.b64decode(
        record["kinesis"]["data"],
        validate=True
    )
    security_event = json.loads(payload)
    validate_security_event(security_event)
    return security_event


def process_security_event(security_event):

    event_type = security_event["event_type"]

    username = security_event["username"]

    source_ip = security_event["source_ip"]

    timestamp = security_event["timestamp"]

    if event_type == "PRIVILEGE_ESCALATION":

        create_alert(
            event_type="PRIVILEGE_ESCALATION",
            username=username,
            source_ip=source_ip,
            severity="HIGH",
            timestamp=timestamp
        )

    elif event_type == "ACCOUNT_LOCKED":

        create_alert(
            event_type="ACCOUNT_LOCKED",
            username=username,
            source_ip=source_ip,
            severity="MEDIUM",
            timestamp=timestamp
        )

    elif event_type == "LOGIN_FAILED":

        count = increment_failed_login(username)

        if count >= 5:

            create_alert(
                event_type="BRUTE_FORCE_ATTACK",
                username=username,
                source_ip=source_ip,
                severity="HIGH",
                timestamp=timestamp
            )

            login_failure_counters_table.delete_item(
                Key={
                    "username": username
                }
            )


def lambda_handler(event, context):

    batch_item_failures = []

    for record in event["Records"]:

        try:
            security_event = decode_security_event(record)
            process_security_event(security_event)
        except (binascii.Error, KeyError, TypeError, ValueError, OverflowError, json.JSONDecodeError) as exc:
            item_identifier = (
                record.get("eventID")
                or record.get("kinesis", {}).get("sequenceNumber")
            )

            if item_identifier:
                batch_item_failures.append(
                    {"itemIdentifier": item_identifier}
                )

            print(
                f"Failed to process Kinesis record "
                f"{item_identifier}: {type(exc).__name__}"
            )

    return {
        "batchItemFailures": batch_item_failures
    }