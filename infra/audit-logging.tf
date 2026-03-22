# 1. Create the "Digital Hard Drive" for your logs
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allows easy cleanup for learning

  tags = local.common_tags
}

# 2. Give CloudTrail permission to "talk" to the bucket
resource "aws_s3_bucket_policy" "allow_cloudtrail" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSCloudTrailWrite",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.audit_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailGetBucketAcl",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Action   = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.audit_logs.arn
      }
    ]
  })
}

# 3. Enable the actual "Security Camera"
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-main-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # This ensures we are following Step 5 of the guide!
  depends_on = [aws_s3_bucket_policy.allow_cloudtrail]
}

# 4. The "Cleanup Crew": Delete anything older than 90 days
resource "aws_s3_bucket_lifecycle_configuration" "retention" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "log_retention"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}
