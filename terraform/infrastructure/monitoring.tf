resource "aws_sns_topic" "security_alerts" {

  name = "${local.project}-${local.environment}-security-alerts"

  kms_master_key_id = "alias/aws/sns"

  tags = local.common_tags
}

variable "alert_email" {
  type        = string
  description = "Email address that receives high-severity alert notifications."

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

resource "aws_cloudwatch_metric_alarm" "high_severity_alerts" {

  alarm_name = "${local.project}-${local.environment}-high-severity-alerts"

  comparison_operator = "GreaterThanOrEqualToThreshold"

  evaluation_periods = 1

  metric_name = "ThreatAlerts"

  namespace = "ThreatAnalyzer"

  period = 300

  statistic = "Sum"

  threshold = 1

  alarm_description = "High severity threats detected"

  treat_missing_data = "notBreaching"

  dimensions = {
    Severity = "HIGH"
  }

  alarm_actions = [
    aws_sns_topic.security_alerts.arn
  ]
}

resource "aws_sns_topic_subscription" "email" {

  topic_arn = aws_sns_topic.security_alerts.arn

  protocol = "email"

  endpoint = var.alert_email
}