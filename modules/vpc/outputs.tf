output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "The URI of the VPC network"
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "The name of the GKE node subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "subnet_id" {
  description = "The ID of the GKE node subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "subnet_self_link" {
  description = "The URI of the GKE node subnet"
  value       = google_compute_subnetwork.gke_subnet.self_link
}

output "pods_range_name" {
  description = "Name of the secondary IP range used for GKE pods"
  value       = "${var.environment}-pods"
}

output "services_range_name" {
  description = "Name of the secondary IP range used for GKE services"
  value       = "${var.environment}-services"
}
