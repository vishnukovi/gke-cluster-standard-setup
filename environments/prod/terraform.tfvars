# ==============================================================================
# Prod Environment — Variable Values
# Replace placeholder values before running terraform apply.
# In CI/CD pipelines, inject sensitive values via environment variables
# (TF_VAR_project_id) or a secrets manager — never hard-code them here.
# ==============================================================================

project_id = "your-gcp-project-id" # ← replace

region = "us-central1"

# Network CIDRs — prod uses 10.10.x.x range (no overlap with dev)
subnet_cidr   = "10.10.0.0/20"
pods_cidr     = "10.11.0.0/16"
services_cidr = "10.12.0.0/20"

# Control plane CIDR — must be /28 and not overlap with any subnet CIDR
master_ipv4_cidr_block = "172.16.1.0/28"

# Restrict API access to your CI/CD runners, VPN gateway, and bastion host.
# Replace with your actual CIDRs.
master_authorized_networks = [
  {
    cidr_block   = "10.0.0.0/8"      # Internal VPC / VPN range
    display_name = "internal-vpn"
  },
  # {
  #   cidr_block   = "1.2.3.4/32"    # GitHub Actions runner (static IP)
  #   display_name = "github-actions"
  # },
]

# Binary Authorization: only allow attested images to run in prod
enable_binary_authorization = true

# Node machine types — n2 series for better performance in prod
system_machine_type = "n2-standard-2"
app_machine_type    = "n2-standard-4"

# Autoscaler bounds — 2 per zone minimum for HA (6 total across 3 zones)
app_min_node_count = 2
app_max_node_count = 10
