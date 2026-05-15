# ==============================================================================
# Dev Environment — Variable Values
# Replace placeholder values before running terraform apply.
# DO NOT commit secrets or real project IDs to source control if this repo is public.
# ==============================================================================

project_id = "your-gcp-project-id" # ← replace

region = "us-central1"
zone   = "us-central1-a"

# Network CIDRs — dev uses 10.0.x.x range
subnet_cidr   = "10.0.0.0/20"
pods_cidr     = "10.1.0.0/16"
services_cidr = "10.2.0.0/20"

# Control plane CIDR — must not overlap with subnet CIDRs
master_ipv4_cidr_block = "172.16.0.0/28"

# In dev, allow all IPs for developer convenience.
# NEVER do this in prod.
master_authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "all-dev-open"
  }
]

# Node machine types — e2 series is cost-optimised for dev workloads
system_machine_type = "e2-standard-2"
app_machine_type    = "e2-standard-4"
