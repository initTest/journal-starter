# 1. Create a "Vault" for our API secrets
resource "aws_secretsmanager_secret" "api_secrets" {
  name        = "${var.project_name}-api-secrets"
  description = "Contains the Database URL and other API keys for the Journal app"

  # Why recovery_window_in_days = 0?
  # This makes it easier to delete and re-create during your learning phase.
  # For real production, you'd usually set this to 7 or 30 days.
  recovery_window_in_days = 0

  tags = local.common_tags

  lifecycle {
    # This prevents the secret from being deleted, even during 'terraform destroy'
    prevent_destroy = true
  }
}
