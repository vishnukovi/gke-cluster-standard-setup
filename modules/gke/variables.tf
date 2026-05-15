# ── Core ──────────────────────────────────────────────────────────────────────

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name — must be one of: dev, staging, prod"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "GKE cluster location. Use a region (e.g., us-central1) for regional HA clusters, or a zone (e.g., us-central1-a) for cheaper zonal clusters"
  type        = string
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Name of the VPC network to deploy the cluster into"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet to deploy the cluster nodes into"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet secondary range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet secondary range for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR range for the GKE control plane (must be /28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_private_endpoint" {
  description = "When true, the Kubernetes API is only accessible from within the VPC (requires VPN or bastion). Set true for highly-sensitive prod clusters"
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of CIDRs authorized to access the Kubernetes API server"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# ── Cluster config ────────────────────────────────────────────────────────────

variable "release_channel" {
  description = "GKE release channel. RAPID for dev (latest features), REGULAR for prod (stability)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "release_channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "maintenance_start_time" {
  description = "Start of the maintenance window (RFC3339, e.g., 2024-01-01T02:00:00Z)"
  type        = string
  default     = "2024-01-01T02:00:00Z"
}

variable "maintenance_end_time" {
  description = "End of the maintenance window (RFC3339, e.g., 2024-01-01T06:00:00Z)"
  type        = string
  default     = "2024-01-01T06:00:00Z"
}

variable "maintenance_recurrence" {
  description = "RRULE for maintenance window recurrence (e.g., weekly on weekends)"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization (enforce image attestation). Recommended for prod"
  type        = bool
  default     = false
}

# ── Node SA ──────────────────────────────────────────────────────────────────

variable "node_service_account_email" {
  description = "Email of the GCP service account to attach to GKE nodes"
  type        = string
}

# ── System node pool ──────────────────────────────────────────────────────────

variable "system_node_count" {
  description = "Number of nodes in the system node pool (per zone for regional clusters)"
  type        = number
  default     = 1

  validation {
    condition     = var.system_node_count >= 1
    error_message = "system_node_count must be at least 1."
  }
}

variable "system_machine_type" {
  description = "Machine type for system nodes"
  type        = string
  default     = "e2-standard-2"
}

# ── Application node pool ─────────────────────────────────────────────────────

variable "app_min_node_count" {
  description = "Minimum number of nodes in the application pool (per zone for regional clusters)"
  type        = number
  default     = 1
}

variable "app_max_node_count" {
  description = "Maximum number of nodes in the application pool (per zone for regional clusters)"
  type        = number
  default     = 5
}

variable "app_machine_type" {
  description = "Machine type for application nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "app_disk_size_gb" {
  description = "Boot disk size in GB for application nodes"
  type        = number
  default     = 100
}

variable "use_spot_instances" {
  description = "Use Spot VMs for application nodes (60-90% cheaper, can be preempted). Recommended for dev"
  type        = bool
  default     = false
}

# ── Labels ────────────────────────────────────────────────────────────────────

variable "node_labels" {
  description = "Additional Kubernetes labels to apply to all nodes"
  type        = map(string)
  default     = {}
}
