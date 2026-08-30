import json
import random
import time
import uuid

from datetime import datetime, timezone

import boto3


REGION = "eu-central-1"
STREAM_NAME = "threat-analyzer-dev-security-events"
TOTAL_EVENTS = 100

kinesis = boto3.client(
    "kinesis",
    region_name = REGION
)

USERS = [
    "alice",
    "bob",
    "charlie",
    "david",
    "admin",
    "guest"
]

APPLICATIONS = [
    "customer-portal",
    "admin-portal",
    "billing-api"
]

NORMAL_EVENTS = [
    "LOGIN_SUCCESS",
    "API_REQUEST",
    "FILE_DOWNLOAD",
    "LOGOUT"
]

THREAT_EVENTS = [
    "LOGIN_FAILED",
    "PRIVILEGE_ESCALATION",
    "ACCOUNT_LOCKED"
]


def create_event(event_type, username, source_ip=None, application=None):
    return {
        "event_id": str(uuid.uuid4()),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event_type": event_type,
        "username": username,
        "source_ip": source_ip or f"10.0.{random.randint(1,10)}.{random.randint(1,254)}",
        "application": application or random.choice(APPLICATIONS)
    }


def generate_random_event():
    username = random.choice(USERS)

    if random.random() < 0.5:
        event_type = random.choice(NORMAL_EVENTS)
    else:
        event_type = random.choice(THREAT_EVENTS)
    
    return create_event(
        event_type=event_type,
        username=username
    )


def generate_bruteforce_attack(username="admin"):

    attack_events = []

    for _ in range(10):
        attack_events.append(
            create_event(
                event_type="LOGIN_FAILED",
                username=username,
                source_ip="10.0.99.99",
                application="admin-portal"
            )
        )

    return attack_events


def send_event(event):

    response = kinesis.put_record(
        StreamName=STREAM_NAME,
        Data=json.dumps(event),
        PartitionKey=event["username"]
    )

    # response = {
    #     "SequenceNumber": random.randint(1, 56546)
    # }

    print(
        f"[{event["event_type"]}] "
        f"user={event["username"]} "
        f"ip={event["source_ip"]} "
        f"seq={response["SequenceNumber"]}"
    )


def main():
    print("Starting security event generator...")
    print(f"Stream: {STREAM_NAME}")

    event_counter = 1
    while event_counter <= TOTAL_EVENTS:

        print(f"\nEvents: {event_counter}")

        try:
            #
            # 10% chance to simulate a brute-force attack
            #
            if random.random() < 0.10 and TOTAL_EVENTS - event_counter > 10:
                
                print("\n*** SIMULATING BRUTE-FORCE ATTACK ***")

                attack_events = generate_bruteforce_attack()

                for event in attack_events:
                    send_event(event)
                    event_counter += 1
                
                print("*** ATTACK COMPLETED ***\n")

                time.sleep(2)
                continue

            #
            # Normal event generation
            #
            event = generate_random_event()
            event_counter += 1

            send_event(event)

            time.sleep(1)

        except KeyboardInterrupt:
            print("\nStopping producer...")
            break

        except Exception as ex:
            print(f"Error: {ex}")
            time.sleep(5)


if __name__ == "__main__":
    main()