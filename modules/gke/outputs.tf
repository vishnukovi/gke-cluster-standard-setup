output "cluster_id" {
  description = "The unique identifier of the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "The location (region or zone) of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "The IP address of the Kubernetes API server"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public certificate for the cluster CA (used for kubectl config)"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_self_link" {
  description = "The URI of the GKE cluster"
  value       = google_container_cluster.primary.self_link
}

output "workload_identity_pool" {
  description = "Workload Identity pool for this cluster (used in IAM bindings)"
  value       = "${var.project_id}.svc.id.goog"
}

output "system_node_pool_name" {
  description = "Name of the system node pool"
  value       = google_container_node_pool.system.name
}

output "app_node_pool_name" {
  description = "Name of the application node pool"
  value       = google_container_node_pool.application.name
}

output "get_credentials_command" {
  description = "gcloud command to configure kubectl for this cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.project_id}"
}
