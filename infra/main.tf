locals {
  project_name = var.project_name
  environment  = var.environment

  # Consolidated tags to apply to EVERYTHING
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {} # Gets your AWS Account ID
data "aws_region" "current" {}          # Gets the current region

# Use this to lookup the ECR policy we discussed
data "aws_iam_policy" "ecr_read_only" {
  name = "AmazonEC2ContainerRegistryReadOnly"
}
