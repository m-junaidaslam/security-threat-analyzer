resource "aws_kinesis_stream" "security_events" {
  name = "${local.project}-${local.environment}-security-events"

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  retention_period = 24

  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"

  tags = local.common_tags
}