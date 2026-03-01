# This policy sits on the ECR side and says "I trust the EKS nodes"
resource "aws_ecr_repository_policy" "journal_policy" {
  repository = aws_ecr_repository.journal_app.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowEKSNodesToPull",
        Effect = "Allow",
        Principal = {
          AWS = module.eks.eks_managed_node_groups["default"].iam_role_arn
        },
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
