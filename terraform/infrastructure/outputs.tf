output "security_events_stream" {
  value = aws_kinesis_stream.security_events.name
}

output "threat_detector_function" {
  value = aws_lambda_function.threat_detector.function_name
}

output "threat_detector_role" {
  value = aws_iam_role.threat_detector.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}