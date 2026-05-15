# ==============================================================================
# Dev Environment
# - Zonal cluster (single zone → lower cost, acceptable for development)
# - RAPID release channel (get new K8s features quickly)
# - Spot VMs on the app node pool (60-90% cost saving)
# - No Binary Authorization (faster iteration)
# - Public control plane endpoint (reachable from developer machines)
# ==============================================================================

# ── VPC ───────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project_id             = var.project_id
  region                 = var.region
  environment            = "dev"
  subnet_cidr            = var.subnet_cidr
  pods_cidr              = var.pods_cidr
  services_cidr          = var.services_cidr
  master_ipv4_cidr_block = var.master_ipv4_cidr_block
}

# ── IAM ───────────────────────────────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = "dev"
}

# ── GKE Cluster ───────────────────────────────────────────────────────────────

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  environment = "dev"

  # Zonal for dev — cheaper than regional, sufficient for development
  location = var.zone

  # Networking (from VPC module)
  vpc_name            = module.vpc.vpc_name
  subnet_name         = module.vpc.subnet_name
  pods_range_name     = module.vpc.pods_range_name
  services_range_name = module.vpc.services_range_name
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # Control plane accessible from public internet (dev convenience)
  enable_private_endpoint = false

  # Allow developer machines to reach the API server
  master_authorized_networks = var.master_authorized_networks

  # RAPID channel: get new Kubernetes versions first
  release_channel = "RAPID"

  # Maintenance: any time is fine for dev
  maintenance_start_time = "2024-01-01T00:00:00Z"
  maintenance_end_time   = "2024-01-01T08:00:00Z"
  maintenance_recurrence = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"

  # No Binary Authorization in dev (faster iteration)
  enable_binary_authorization = false

  # Node SA from IAM module
  node_service_account_email = module.iam.gke_node_sa_email

  # System pool — minimal footprint for dev
  system_node_count   = 1
  system_machine_type = var.system_machine_type

  # App pool — small, auto-scales, uses Spot VMs
  app_min_node_count = 1
  app_max_node_count = 3
  app_machine_type   = var.app_machine_type
  app_disk_size_gb   = 50
  use_spot_instances = true # ~60-90% cheaper, acceptable for dev

  node_labels = {
    env = "dev"
  }

  depends_on = [module.vpc, module.iam]
}
