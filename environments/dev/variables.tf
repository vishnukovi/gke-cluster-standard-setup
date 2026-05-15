variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region (e.g., us-central1)"
  type        = string
}

variable "zone" {
  description = "The GCP zone for the zonal dev cluster (e.g., us-central1-a)"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE node subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR range for the GKE control plane (/28)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs authorized to access the Kubernetes API server"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all-dev" # Open in dev for convenience; tighten in prod
    }
  ]
}

variable "system_machine_type" {
  description = "Machine type for system nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "app_machine_type" {
  description = "Machine type for application nodes"
  type        = string
  default     = "e2-standard-4"
}
