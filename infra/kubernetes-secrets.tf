
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
