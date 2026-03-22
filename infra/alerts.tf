# 1. Create a Topic (The "Megaphone")
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-security-alerts"

  tags = local.common_tags
}

# 2. Subscribe your Email (The "Listener")
# Note: You MUST go to your email inbox and click "Confirm Subscription" 
# after running terraform apply!
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 3. Create the "Sensor" Rule
resource "aws_cloudwatch_event_rule" "sg_changes" {
  name        = "detect-security-group-changes"
  description = "Alerts when a Security Group rule is added or removed"

  # The "Logic": We only want to hear about Security Group API calls
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail" : {
      "eventSource" : ["ec2.amazonaws.com"],
      "eventName" : [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress"
      ]
    }
  })
}

# 4. Connect the rule to the SNS topic
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.sg_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

# 🔑 THIS IS THE KEY: We must give EventBridge permission to publish to SNS
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudWatchEvents",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}
