module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "journal-cluster"
  cluster_version = var.eks_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  enable_irsa                    = true # This turns on the OIDC bridge

  # Managed Node Groups (The EC2 instances)
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = var.eks_instance_types
      capacity_type  = "SPOT" # Saves up to 90% cost for practice
      iam_role_additional_policies = {
        ECRPull = data.aws_iam_policy.ecr_read_only.arn
      }
    }
  }

  tags = local.common_tags
}
