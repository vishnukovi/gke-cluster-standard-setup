output "gke_node_sa_email" {
  description = "Email of the GKE node service account (used in node pool config)"
  value       = google_service_account.gke_node_sa.email
}

output "gke_node_sa_id" {
  description = "Unique numeric ID of the GKE node service account"
  value       = google_service_account.gke_node_sa.unique_id
}

output "gke_node_sa_name" {
  description = "Fully-qualified name of the GKE node service account"
  value       = google_service_account.gke_node_sa.name
}
