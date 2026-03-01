resource "aws_security_group" "rds_sg" {
  name        = "journal-rds-sg"
  description = "Allow traffic from EKS to RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    # This allows any resource in the EKS cluster security group to connect
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/16"]
  }

}

resource "aws_db_subnet_group" "journal_db_subnets" {
  name       = "journal-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "Journal DB Subnet Group"
  }
}

resource "aws_db_instance" "journal_db" {
  allocated_storage    = 20
  db_name              = "journal_db"
  engine               = "postgres"
  engine_version       = var.db_engine_version # Specifying Postgres 15
  instance_class       = var.db_instance_class
  username             = "postgres"
  password             = var.db_password
  parameter_group_name = "default.postgres15"

  db_subnet_group_name   = aws_db_subnet_group.journal_db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false # Keep it internal to the VPC
}
