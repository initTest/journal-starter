output "ecr_repository_url" {
  value = aws_ecr_repository.journal_app.repository_url
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.journal_db.endpoint
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The public endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

# This is the most helpful output - a literal command to run
output "kubeconfig_command" {
  description = "Run this command to update your local kubeconfig and connect to the cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}
