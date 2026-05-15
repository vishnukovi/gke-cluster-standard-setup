output "cluster_name" {
  description = "Name of the prod GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Location (region) of the prod GKE cluster"
  value       = module.gke.cluster_location
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "vpc_name" {
  description = "Name of the prod VPC"
  value       = module.vpc.vpc_name
}

output "node_service_account" {
  description = "Email of the GKE node service account"
  value       = module.iam.gke_node_sa_email
}

output "workload_identity_pool" {
  description = "Workload Identity pool for IAM bindings"
  value       = module.gke.workload_identity_pool
}

output "get_credentials_command" {
  description = "Run this command to configure kubectl"
  value       = module.gke.get_credentials_command
}
