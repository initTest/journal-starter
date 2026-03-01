
module "vpc" {
  source = "./vpc"
  project_name            = local.name
  common_tags             = local.common_tags
  vpc_name                = "cloud-learn-vpc"
}

module "ec2" {
  source = "./ec2"
  vpc_id      = module.vpc.vpc_id
  common_tags = local.common_tags
  instance_type = "t3.micro"
  instance_keypair = "terraform-key"
  vpc_public_subnets = module.vpc.public_subnets
  environment = local.environment
}