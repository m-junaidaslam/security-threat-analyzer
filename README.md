# Threat Analyzer

A serverless, event-driven security monitoring platform built on AWS.

The platform ingests security events in real time, detects suspicious activities, stores alerts for investigation, archives raw events for long-term retention, and notifies security teams when critical threats are detected.

---

# Quick Start

## Prerequisites

Before running this project, make sure you have:

- Python 3.13+
- AWS CLI configured with valid credentials
- Terraform 1.15.0 or newer
- An AWS account with permissions to create the required resources

## 1. Clone the Repository

```bash
git clone <your-repository-url>
cd security-threat-analyzer-main
```

## 2. Create a Virtual Environment

```bash
python -m venv .venv
source .venv/bin/activate
```

On Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

## 3. Install Python Dependencies

```bash
python -m pip install --upgrade pip
pip install ".[dev]"
```

## 4. Build the Lambda Package

The Terraform configuration expects a zip file for the Lambda handler.

```bash
zip -j lambdas/threat_detector/threat_detector.zip lambdas/threat_detector/threat_detector.py
```

## 5. Bootstrap Terraform State

```bash
cd terraform/backend-bootstrap
terraform init
terraform apply
```

Copy the output value for `terraform_state_bucket`, then initialize the infrastructure backend:

```bash
cd ../infrastructure
terraform init \
  -backend-config="bucket=<terraform_state_bucket_output>" \
  -backend-config="region=eu-central-1" \
  -backend-config="encrypt=true"
```

## 6. Configure Deployment Variables

Copy the example variable file and adjust the values for your environment:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Example:

```hcl
aws_region  = "eu-central-1"
project     = "threat-analyzer"
environment = "dev"
alert_email = "security-alerts@example.com"
```

## 7. Deploy the Infrastructure

```bash
terraform plan
terraform apply
```

## 8. Generate Security Events

```bash
cd ../..
python producer.py
```

This sends sample security events into the Kinesis stream for processing.

## 9. Query Alerts

```bash
python investigation/query_alerts.py --user admin
```

This retrieves alert records from the DynamoDB tables for investigation and review.

---

# Architecture

```text
Security Event Generator
           |
           v
      Kinesis Stream
           |
    +------+------+
    |             |
    v             v
Lambda       Firehose
    |             |
    v             v
DynamoDB         S3
    |
    v
CloudWatch Metrics
    |
    v
CloudWatch Alarm
    |
    v
SNS Email Notifications
```

---

# Features

## Real-Time Event Processing

Security events are published to an Amazon Kinesis Data Stream and processed in near real time by AWS Lambda.

Supported event types:

- LOGIN_FAILED
- ACCOUNT_LOCKED
- PRIVILEGE_ESCALATION

---

## Threat Detection

### Privilege Escalation

Generates a HIGH severity alert.

Example:

```json
{
  "event_type": "PRIVILEGE_ESCALATION",
  "username": "admin"
}
```

Result:

```text
HIGH ALERT
```

---

### Account Locked

Generates a MEDIUM severity alert.

Example:

```json
{
  "event_type": "ACCOUNT_LOCKED",
  "username": "alice"
}
```

Result:

```text
MEDIUM ALERT
```

---

### Brute Force Detection

The platform tracks failed login attempts using DynamoDB.

After a configurable threshold of failed login attempts, a HIGH severity BRUTE_FORCE_ATTACK alert is generated.

Example flow:

```text
LOGIN_FAILED
LOGIN_FAILED
LOGIN_FAILED
LOGIN_FAILED
LOGIN_FAILED
        |
        v
BRUTE_FORCE_ATTACK
```

---

# Components

## Amazon Kinesis Data Streams

Responsible for ingesting security events.

Benefits:

- Real-time ingestion
- Durable event storage
- Multiple consumers
- Scalable architecture

---

## AWS Lambda

Consumes events from Kinesis.

Responsibilities:

- Parse incoming records
- Evaluate threat conditions
- Create alert records
- Publish CloudWatch metrics

---

## Amazon DynamoDB

### Threat Alerts Table

Stores generated alerts.

Example:

```json
{
  "alert_id": "12345",
  "event_type": "BRUTE_FORCE_ATTACK",
  "severity": "HIGH",
  "username": "admin",
  "source_ip": "10.0.1.10",
  "event_timestamp": 1786452000
}
```

Features:

- Pay-per-request billing
- Point-in-time recovery (PITR)
- TTL-based cleanup

---

### Login Failure Counters Table

Stores failed login counters used for brute-force detection.

Example:

```json
{
  "username": "admin",
  "failed_login_count": 4
}
```

---

# Global Secondary Indexes (GSI)

## username-index

Partition Key:

```text
username
```

Sort Key:

```text
event_timestamp
```

Supports investigations such as:

```text
Show all alerts for admin
```

---

## severity-index

Partition Key:

```text
severity
```

Sort Key:

```text
event_timestamp
```

Supports investigations such as:

```text
Show all HIGH alerts
```

---

# Amazon S3

Used for long-term archival of raw security events.

Events are delivered via Kinesis Firehose.

Example structure:

```text
events/
└── year=2026/
    └── month=08/
        └── day=11/
```

Features:

- Server-side encryption
- Versioning enabled
- Public access blocked
- GZIP compression

---

# Amazon Kinesis Firehose

Streams all security events into S3.

Benefits:

- Long-term retention
- Cost-efficient storage
- Audit trail
- Future analytics

---

# Monitoring & Alerting

## CloudWatch Custom Metrics

Namespace:

```text
ThreatAnalyzer
```

Metric:

```text
ThreatAlerts
```

Dimension:

```text
Severity
```

Example:

```text
Severity=HIGH
```

---

## CloudWatch Alarms

Monitors:

```text
HIGH severity alerts
```

When the defined threshold is exceeded:

```text
Alarm State
    |
    v
SNS Notification
```

---

## SNS Notifications

Email notifications are sent whenever a CloudWatch alarm enters the ALARM state.

---

# Security Controls

- Kinesis server-side encryption using the AWS-managed KMS key
- S3 archive encryption, versioning, public-access blocking, and lifecycle expiration
- DynamoDB point-in-time recovery and TTL cleanup
- Explicit CloudWatch log retention
- Least-privilege IAM policies scoped to application resources
- Per-record validation and partial batch failure reporting for Kinesis events

This is a demonstration project. Before production use, review retention periods,
KMS key strategy, IAM permissions, alert delivery, and operational access for the
target environment.

---

# Infrastructure as Code

The entire platform is deployed using Terraform.

## Services Provisioned

- Kinesis Data Streams
- Lambda
- IAM Roles and Policies
- DynamoDB
- DynamoDB GSIs
- S3
- Firehose
- CloudWatch Metrics
- CloudWatch Alarms
- SNS

---

# Project Structure

```text
threat-analyzer/
│
├── producer/
│   └── producer.py
│
├── investigation/
│   └── query_alerts.py
│
├── lambdas/
│   └── threat_detector/
│       ├── threat_detector.py
│       └── threat_detector.py
│
└── terraform/
    ├── backend-bootstrap/
    │   ├── backend.tf
    │   ├── main.tf
    │   └── outputs.tf
    │
    └── infrastructure/
        ├── provider.tf
        ├── versions.tf
        ├── locals.tf
        ├── kinesis.tf
        ├── iam.tf
        ├── dynamodb.tf
        ├── lambda.tf
        ├── firehose.tf
        ├── monitoring.tf
        └── outputs.tf
```

---

# Deployment

## Bootstrap Backend

```bash
cd terraform/backend-bootstrap

terraform init
terraform apply
```

The bootstrap stack uses local state because it creates the remote state bucket.
Copy the `terraform_state_bucket` output, then initialize the infrastructure backend:

```bash
cd terraform/infrastructure

terraform init \
  -backend-config="bucket=<terraform_state_bucket_output>" \
  -backend-config="region=eu-central-1" \
  -backend-config="encrypt=true"
```

Copy `terraform.tfvars.example` to a local `terraform.tfvars` file and replace
`alert_email` with the address that should receive SNS confirmations. The local
`terraform.tfvars` file is ignored by Git.

---

## Deploy Infrastructure

```bash
cd terraform/infrastructure

terraform init
terraform plan
terraform apply
```

The AWS region, project name, environment, and alert email are configurable Terraform
variables. Supply AWS credentials through the AWS CLI environment or an approved IAM
identity mechanism; never commit credentials to this repository.

---

# Generate Events

Run:

```bash
python producer.py
```

This will send security events into Kinesis.

---

# Investigations

## Query by User

```bash
python query_alerts.py --user admin
```

Example output:

```text
Found 8 alerts

BRUTE_FORCE_ATTACK
PRIVILEGE_ESCALATION
ACCOUNT_LOCKED
```

---

## Query by Severity

```bash
python query_alerts.py --severity HIGH
```

Example output:

```text
Found 15 alerts

BRUTE_FORCE_ATTACK
PRIVILEGE_ESCALATION
```

---

# Validation Commands

## Verify Lambda Logs

```bash
aws logs tail \
/aws/lambda/threat-analyzer-dev-threat-detector \
--follow \
--region eu-central-1
```

---

## Verify Alerts Table

```bash
aws dynamodb scan \
  --table-name threat-analyzer-dev-threat-alerts \
  --region eu-central-1
```

---

## Verify S3 Archive

```bash
aws s3 ls s3://<archive-bucket> --recursive
```

---

## Verify Alarm

```bash
aws cloudwatch describe-alarms \
  --region eu-central-1
```

---

# Learning Outcomes

This project demonstrates practical experience with:

- AWS Kinesis Data Streams
- AWS Lambda
- DynamoDB
- DynamoDB GSIs
- DynamoDB TTL
- DynamoDB PITR
- Amazon S3
- Amazon Kinesis Firehose
- CloudWatch Metrics
- CloudWatch Alarms
- SNS Notifications
- IAM Least Privilege Design
- Terraform Infrastructure as Code
- Event-Driven Architectures
- Real-Time Threat Detection
- Security Monitoring Workflows

---

# Future Enhancements

- Web dashboard
- API Gateway integration
- IP reputation enrichment
- Threat scoring
- Grafana dashboards
- OpenSearch integration
- Multi-region failover
- Machine learning anomaly detection

---

# Author

Muhammad Junaid Aslam

Serverless Security Analytics Platform built for learning and demonstrating AWS event-driven architecture, infrastructure as code, and threat detection workflows.