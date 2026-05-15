variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the regional prod cluster (e.g., us-central1)"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE node subnet"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.11.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.12.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR range for the GKE control plane (/28, must not overlap with subnet CIDRs)"
  type        = string
  default     = "172.16.1.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs authorized to access the Kubernetes API server. Lock this down to CI/CD, VPN, or bastion IPs"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_binary_authorization" {
  description = "Enable Binary Authorization policy enforcement"
  type        = bool
  default     = true
}

variable "system_machine_type" {
  description = "Machine type for system nodes"
  type        = string
  default     = "n2-standard-2"
}

variable "app_machine_type" {
  description = "Machine type for application nodes"
  type        = string
  default     = "n2-standard-4"
}

variable "app_min_node_count" {
  description = "Minimum number of application nodes per zone"
  type        = number
  default     = 2
}

variable "app_max_node_count" {
  description = "Maximum number of application nodes per zone"
  type        = number
  default     = 10
}
