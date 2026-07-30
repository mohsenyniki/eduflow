output "s3_raw_bucket" {
  description = "Name of the raw zone S3 bucket"
  value       = module.s3.raw_bucket_name
}

output "s3_curated_bucket" {
  description = "Name of the curated zone S3 bucket"
  value       = module.s3.curated_bucket_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL connection endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "eks_cluster_name" {
  description = "EKS cluster name for kubectl configuration"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}