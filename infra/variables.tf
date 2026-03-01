# --- Global Variables ---
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "journal-app"
}
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# --- Network Variables ---
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# --- EKS Variables ---
variable "eks_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"
}
variable "eks_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

# --- Database Variables ---
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
variable "db_password" {
  description = "RDS root password"
  type        = string
  sensitive   = true # This prevents the password from showing in terminal output
}

variable "db_engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "15.10"
}
