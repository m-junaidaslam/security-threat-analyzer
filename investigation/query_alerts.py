import argparse
from pprint import pprint

import boto3
from boto3.dynamodb.conditions import Key

REGION = "eu-central-1"
TABLE_NAME = "threat-analyzer-dev-threat-alerts"

dynamodb = boto3.resource(
    "dynamodb",
    region_name=REGION
)

table = dynamodb.Table(TABLE_NAME)


def query_by_user(username):

    response = table.query(
        IndexName="username-index",
        KeyConditionExpression=Key("username").eq(username.lower()),
        ScanIndexForward=False
    )

    return response.get("Items", [])


def query_by_severity(severity):

    response = table.query(
        IndexName="severity-index",
        KeyConditionExpression=Key("severity").eq(severity.upper()),
        ScanIndexForward=False
    )

    return response.get("Items", [])


def print_results(items):

    if not items:
        print("No results found.")
        return

    print(f"\nFound {len(items)} alert(s)\n")

    for item in items:

        print("-" * 80)

        print(f"Alert ID   : {item.get('alert_id')}")
        print(f"Event Type : {item.get('event_type')}")
        print(f"Severity   : {item.get('severity')}")
        print(f"Username   : {item.get('username')}")
        print(f"Source IP  : {item.get('source_ip')}")
        print(f"Timestamp  : {item.get('timestamp')}")

    print("-" * 80)


def main():

    parser = argparse.ArgumentParser(
        description="Query Threat Analyzer alerts"
    )

    group = parser.add_mutually_exclusive_group(required=True)

    group.add_argument(
        "--user",
        help="Query alerts by username"
    )

    group.add_argument(
        "--severity",
        choices=["HIGH", "MEDIUM", "LOW"],
        help="Query alerts by severity"
    )

    args = parser.parse_args()

    if args.user:
        alerts = query_by_user(args.user)
        print_results(alerts)

    elif args.severity:
        alerts = query_by_severity(args.severity)
        print_results(alerts)


if __name__ == "__main__":
    main()