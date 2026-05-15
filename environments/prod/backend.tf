# ==============================================================================
# Remote State Backend — Prod
# Prod state is stored in a separate GCS prefix (or a separate bucket entirely)
# to prevent accidental cross-environment state operations.
#
# Create the bucket BEFORE running terraform init:
#   gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-tfstate
#   gsutil versioning set on gs://YOUR_PROJECT_ID-tfstate
#   gsutil ubla set on gs://YOUR_PROJECT_ID-tfstate
# ==============================================================================

terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-tfstate" # ← replace with your GCS bucket name
    prefix = "gke/prod"
  }

  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
