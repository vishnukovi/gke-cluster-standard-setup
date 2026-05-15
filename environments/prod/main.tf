# ==============================================================================
# Prod Environment
# - Regional cluster (multi-zone → high availability, control-plane SLA)
# - REGULAR release channel (well-tested, ~2-3 months behind RAPID)
# - Standard VMs on app pool (no preemption risk)
# - Binary Authorization enabled (enforce signed images)
# - Master authorized networks locked down to known CIDRs
# - Maintenance windows restricted to weekends
# ==============================================================================

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project_id             = var.project_id
  region                 = var.region
  environment            = "prod"
  subnet_cidr            = var.subnet_cidr
  pods_cidr              = var.pods_cidr
  services_cidr          = var.services_cidr
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
}

# ── IAM ───────────────────────────────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = "prod"
}

# ── GKE Cluster ───────────────────────────────────────────────────────────────

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  environment = "prod"

  # Regional cluster: nodes spread across 3 zones → survives a zone failure
  location = var.region

  # Networking (from VPC module)
  vpc_name            = module.vpc.vpc_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # Keep control plane endpoint public but restrict via master_authorized_networks
  # Set true + use Cloud VPN/IAP if stricter isolation is required
  enable_private_endpoint = false

  # Only allow known CIDRs (CI/CD runners, bastion, VPN) to reach the API server
  master_authorized_networks = var.master_authorized_networks

  # REGULAR channel: stable, well-tested versions, ~2-3 months behind RAPID
  release_channel = "REGULAR"

  # Maintenance: weekends only, 02:00-06:00 UTC (low-traffic window)
  maintenance_start_time = "2024-01-01T02:00:00Z"
  maintenance_end_time   = "2024-01-01T06:00:00Z"
  maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"

  # Binary Authorization: only deploy attested images
  enable_binary_authorization = var.enable_binary_authorization

  # Node SA from IAM module
  node_service_account_email = module.iam.gke_node_sa_email

  # System pool — 1 node per zone (3 total for a regional cluster)
  system_node_count   = 1
  system_machine_type = var.system_machine_type

  # App pool — auto-scales, standard (non-Spot) VMs for reliability
  app_min_node_count = var.app_min_node_count
  app_max_node_count = var.app_max_node_count
  app_machine_type   = var.app_machine_type
  app_disk_size_gb   = 100
  use_spot_instances = false # Never use Spot in prod

  node_labels = {
    env = "prod"
  }

  depends_on = [module.vpc, module.iam]
}
