resource "aws_s3_bucket" "security_event_archive" {

  bucket = "${local.project}-${local.environment}-security-events-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "security_event_archive" {

  bucket = aws_s3_bucket.security_event_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "security_event_archive" {

  bucket = aws_s3_bucket.security_event_archive.id

  rule {
    id     = "expire-archived-events"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "security_event_archive" {

  bucket = aws_s3_bucket.security_event_archive.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_event_archive" {

  bucket = aws_s3_bucket.security_event_archive.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "firehose_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {

      type = "Service"

      identifiers = [
        "firehose.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "firehose" {

  name = "${local.project}-${local.environment}-firehose-role"

  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "firehose_s3" {

  statement {

    effect = "Allow"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]

    resources = [
      aws_s3_bucket.security_event_archive.arn,
      "${aws_s3_bucket.security_event_archive.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "firehose_s3" {

  name = "${local.project}-${local.environment}-firehose-s3"

  policy = data.aws_iam_policy_document.firehose_s3.json
}

resource "aws_iam_role_policy_attachment" "firehose_s3" {

  role = aws_iam_role.firehose.name

  policy_arn = aws_iam_policy.firehose_s3.arn
}

resource "aws_kinesis_firehose_delivery_stream" "security_events" {

  name = "${local.project}-${local.environment}-security-events-delivery"

  destination = "extended_s3"

  kinesis_source_configuration {

    kinesis_stream_arn = aws_kinesis_stream.security_events.arn

    role_arn = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {

    role_arn = aws_iam_role.firehose.arn

    bucket_arn = aws_s3_bucket.security_event_archive.arn

    buffering_size     = 1
    buffering_interval = 60

    compression_format = "GZIP"

    prefix = "events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
  }
}

data "aws_iam_policy_document" "firehose_kinesis" {

  statement {

    effect = "Allow"

    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]

    resources = [
      aws_kinesis_stream.security_events.arn
    ]
  }
}

resource "aws_iam_policy" "firehose_kinesis" {

  name = "${local.project}-${local.environment}-firehose-kinesis"

  policy = data.aws_iam_policy_document.firehose_kinesis.json
}

resource "aws_iam_role_policy_attachment" "firehose_kinesis" {

  role = aws_iam_role.firehose.name

  policy_arn = aws_iam_policy.firehose_kinesis.arn
}