resource "aws_lambda_function" "threat_detector" {
  function_name = "${local.project}-${local.environment}-threat-detector"
  filename      = "../../lambdas/threat_detector/threat_detector.zip"
  source_code_hash = filebase64sha256(
    "../../lambdas/threat_detector/threat_detector.zip"
  )
  role        = aws_iam_role.threat_detector.arn
  handler     = "threat_detector.lambda_handler"
  runtime     = "python3.13"
  timeout     = 30
  memory_size = 256
  environment {
    variables = {
      THREAT_ALERTS_TABLE          = aws_dynamodb_table.threat_alerts.name
      LOGIN_FAILURE_COUNTERS_TABLE = aws_dynamodb_table.login_failure_counters.name
    }
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "threat_detector" {
  name              = "/aws/lambda/${aws_lambda_function.threat_detector.function_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_lambda_event_source_mapping" "security_events" {
  event_source_arn        = aws_kinesis_stream.security_events.arn
  function_name           = aws_lambda_function.threat_detector.arn
  starting_position       = "LATEST"
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
  enabled                 = true
}