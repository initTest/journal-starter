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


# 1. Define the IAM Role for the Journal API
resource "aws_iam_role" "journal_api_role" {
  name = "${var.project_name}-api-role"

  # Trust policy: This allows the EKS cluster's identity provider (OIDC) 
  # to grant this role to a specific Kubernetes Service Account.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Condition = {
          StringEquals = {
            # This restricts the role so ONLY the 'journal-api' ServiceAccount 
            # in the 'default' namespace can use it.
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:default:journal-api-sa"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}


# 2. Define the specific permissions for the API
resource "aws_iam_policy" "journal_api_policy" {
  name        = "${var.project_name}-api-policy"
  description = "Minimal permissions for Journal API"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Database Access (If using RDS IAM Auth)
      {
        Effect   = "Allow",
        Action   = "rds-db:connect",
        Resource = "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.journal_db.resource_id}/*"
      },
      # Registry Access (Pulling the image)
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = aws_ecr_repository.journal_app.arn
      },
      # NEW: Grant the "Secrets Read" permission
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = aws_secretsmanager_secret.api_secrets.arn
      }
    ]
  })
}

# 3. Attach the policy to the Role
resource "aws_iam_role_policy_attachment" "api_attach" {
  role       = aws_iam_role.journal_api_role.name
  policy_arn = aws_iam_policy.journal_api_policy.arn
}
