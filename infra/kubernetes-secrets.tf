resource "kubernetes_secret" "journal_api_secrets" {
  metadata {
    name      = "journal-api-secrets"
    namespace = "default" # This ensures it's in the same namespace as your app
  }

  data = {
    # We construct the full URL using the database information from rds.tf
    # Note: .endpoint includes both the address AND the port (e.g. host:5432)
    DATABASE_URL = format(
      "postgresql://%s:%s@%s/%s?sslmode=require",
      aws_db_instance.journal_db.username,
      var.db_password,
      aws_db_instance.journal_db.endpoint,
      aws_db_instance.journal_db.db_name
    )
  }

  type = "Opaque"

  # Why use depends_on?
  # This tells Terraform: "Don't try to create the secret until the EKS cluster is fully ready."
  depends_on = [module.eks, aws_db_instance.journal_db]
}

resource "kubernetes_service_account" "journal_api_sa" {
  metadata {
    name      = "journal-api-sa"
    namespace = "default"
    annotations = {
      # This is the "Magic Link" that tells EKS which IAM role to give this SA
      "eks.amazonaws.com/role-arn" = aws_iam_role.journal_api_role.arn
    }
  }

  # Ensure the EKS cluster is ready before creating this
  depends_on = [module.eks]
}
