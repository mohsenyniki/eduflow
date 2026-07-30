# ── PROVIDER ──────────────────────────────────────────────────────────────────
# tells Terraform to use AWS and which region

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # stores terraform state in S3 so the whole team shares the same state
  # comment this out on first run, create the bucket manually first
  # backend "s3" {
  #   bucket = "eduflow-terraform-state"
  #   key    = "production/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── S3 BUCKETS ────────────────────────────────────────────────────────────────

module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
  environment  = var.environment
}

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

# ── RDS POSTGRESQL ────────────────────────────────────────────────────────────

module "rds" {
  source       = "./modules/rds"
  project_name = var.project_name
  environment  = var.environment
  db_username  = var.db_username
  db_password  = var.db_password
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
}

# ── EKS CLUSTER ───────────────────────────────────────────────────────────────

module "eks" {
  source       = "./modules/eks"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
}