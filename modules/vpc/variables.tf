variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources (e.g., us-central1)"
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

variable "subnet_cidr" {
  description = "Primary CIDR range for the GKE node subnet"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr must be a valid CIDR block."
  }
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods (alias IP range, /16 recommended)"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.pods_cidr))
    error_message = "pods_cidr must be a valid CIDR block."
  }
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services (alias IP range, /20 recommended)"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.services_cidr))
    error_message = "services_cidr must be a valid CIDR block."
  }
}

variable "master_ipv4_cidr_block" {
  description = "CIDR range for the GKE control plane. Must be a /28 that does not overlap with any subnet CIDRs"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrnetmask(var.master_ipv4_cidr_block))
    error_message = "master_ipv4_cidr_block must be a valid CIDR block (use /28)."
  }
}
