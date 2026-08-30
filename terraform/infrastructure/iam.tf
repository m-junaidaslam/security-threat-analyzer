data "aws_iam_policy_document" "threat_detector_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {

      type = "Service"

      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "threat_detector" {

  name = "${local.project}-${local.environment}-threat-detector-role"

  assume_role_policy = data.aws_iam_policy_document.threat_detector_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "threat_detector_kinesis" {

  statement {

    effect = "Allow"

    actions = [
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:SubscribeToShard"
    ]

    resources = [
      aws_kinesis_stream.security_events.arn
    ]
  }
}

resource "aws_iam_policy" "threat_detector_kinesis" {

  name = "${local.project}-${local.environment}-threat-detector-kinesis"

  policy = data.aws_iam_policy_document.threat_detector_kinesis.json
}

data "aws_iam_policy_document" "threat_detector_logging" {

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.project}-${local.environment}-threat-detector:*"
    ]
  }
}

resource "aws_iam_policy" "threat_detector_logging" {

  name   = "${local.project}-${local.environment}-threat-detector-logging"
  policy = data.aws_iam_policy_document.threat_detector_logging.json
}

resource "aws_iam_role_policy_attachment" "threat_detector_logging" {

  role       = aws_iam_role.threat_detector.name
  policy_arn = aws_iam_policy.threat_detector_logging.arn
}

resource "aws_iam_role_policy_attachment" "threat_detector_kinesis" {

  role = aws_iam_role.threat_detector.name

  policy_arn = aws_iam_policy.threat_detector_kinesis.arn
}

data "aws_iam_policy_document" "threat_detector_dynamodb" {

  statement {

    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      aws_dynamodb_table.threat_alerts.arn,
      aws_dynamodb_table.login_failure_counters.arn
    ]
  }
}

resource "aws_iam_policy" "threat_detector_dynamodb" {

  name = "${local.project}-${local.environment}-threat-detector-dynamodb"

  policy = data.aws_iam_policy_document.threat_detector_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "threat_detector_dynamodb" {

  role = aws_iam_role.threat_detector.name

  policy_arn = aws_iam_policy.threat_detector_dynamodb.arn
}

data "aws_iam_policy_document" "threat_detector_cloudwatch" {

  statement {

    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "threat_detector_cloudwatch" {

  name = "${local.project}-${local.environment}-threat-detector-cloudwatch"

  policy = data.aws_iam_policy_document.threat_detector_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "threat_detector_cloudwatch" {

  role = aws_iam_role.threat_detector.name

  policy_arn = aws_iam_policy.threat_detector_cloudwatch.arn
}