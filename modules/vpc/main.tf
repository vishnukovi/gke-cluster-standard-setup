# ==============================================================================
# VPC Module
# Creates: VPC, GKE subnet with secondary ranges, Cloud Router, Cloud NAT,
#          and firewall rules following least-privilege principles.
# ==============================================================================

resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = var.project_id
  description             = "VPC network for ${var.environment} GKE cluster"
}

# Primary subnet for GKE nodes with secondary ranges for pods and services
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.environment}-gke-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
  description   = "GKE subnet for ${var.environment}"

  # Allows nodes to reach Google APIs without public IPs
  private_ip_google_access = true

  # Secondary ranges required for VPC-native (alias IP) GKE clusters
  secondary_ip_range {
    range_name    = "${var.environment}-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.environment}-services"
    ip_cidr_range = var.services_cidr
  }

  # VPC Flow Logs for network visibility and incident response
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router is required for Cloud NAT
resource "google_compute_router" "router" {
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

# Cloud NAT allows private nodes to reach the internet (e.g., pull container images)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  project                            = var.project_id

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ── Firewall Rules ─────────────────────────────────────────────────────────────

# Allow traffic between nodes, pods, and services within the VPC
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.environment}-allow-internal"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  priority    = 1000
  direction   = "INGRESS"
  description = "Allow internal traffic between nodes, pods, and services"

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
  allow { protocol = "sctp" }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr,
  ]
}

# Required for GCP L4/L7 load balancer health checks
resource "google_compute_firewall" "allow_health_checks" {
  name        = "${var.environment}-allow-health-checks"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  priority    = 1000
  direction   = "INGRESS"
  description = "Allow GCP load balancer health probes"

  allow { protocol = "tcp" }

  source_ranges = [
    "35.191.0.0/16",  # Google health check range
    "130.211.0.0/22", # Google health check range
  ]
}

# Allow GKE control plane to reach nodes (webhooks, metrics, log streaming)
resource "google_compute_firewall" "allow_master_to_nodes" {
  name        = "${var.environment}-allow-master-nodes"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  priority    = 1000
  direction   = "INGRESS"
  description = "Allow GKE control plane to reach nodes for webhooks and metrics"

  allow {
    protocol = "tcp"
    ports    = ["443", "8443", "9443", "10250", "15017"]
  }

  source_ranges = [var.master_ipv4_cidr_block]
}
