resource "aws_dynamodb_table" "threat_alerts" {
  name         = "${local.project}-${local.environment}-threat-alerts"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "alert_id"

  attribute {
    name = "alert_id"
    type = "S"
  }

  attribute {
    name = "username"
    type = "S"
  }

  attribute {
    name = "severity"
    type = "S"
  }

  attribute {
    name = "event_timestamp"
    type = "N"
  }

  global_secondary_index {
    name            = "username-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "username"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "event_timestamp"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "severity-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "severity"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "event_timestamp"
      key_type       = "RANGE"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "login_failure_counters" {
  name         = "${local.project}-${local.environment}-login-failure-counters"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "username"

  attribute {
    name = "username"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = local.common_tags
}