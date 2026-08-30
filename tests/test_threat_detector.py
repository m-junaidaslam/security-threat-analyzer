import os

import pytest

os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")
os.environ.setdefault("AWS_EC2_METADATA_DISABLED", "true")
os.environ.setdefault("THREAT_ALERTS_TABLE", "test-threat-alerts")
os.environ.setdefault("LOGIN_FAILURE_COUNTERS_TABLE", "test-login-failures")

from lambdas.threat_detector.threat_detector import validate_security_event


def valid_event():
    return {
        "event_type": "LOGIN_FAILED",
        "username": "admin",
        "source_ip": "10.0.1.10",
        "timestamp": "2026-08-29T12:00:00+00:00",
    }


def test_validate_security_event_accepts_valid_event():
    validate_security_event(valid_event())


@pytest.mark.parametrize(
    "field, value",
    [
        ("event_type", "UNSUPPORTED"),
        ("username", ""),
        ("source_ip", "not-an-ip"),
        ("timestamp", "2026-08-29T12:00:00"),
    ],
)
def test_validate_security_event_rejects_invalid_values(field, value):
    event = valid_event()
    event[field] = value

    with pytest.raises(ValueError):
        validate_security_event(event)