# ==============================================================================
# IAM Module
# Creates a dedicated, least-privilege service account for GKE nodes.
# Using the default Compute Engine SA for GKE is a security anti-pattern —
# it carries project-editor rights. This SA carries only what GKE needs.
#
# Workload Identity: individual workloads must bind their own K8s service
# accounts to GCP service accounts. See the comment at the bottom.
# ==============================================================================

resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.environment}-gke-node-sa"
  display_name = "GKE Node SA [${var.environment}]"
  description  = "Least-privilege service account for GKE nodes in the ${var.environment} environment"
  project      = var.project_id
}

# ── Minimum required IAM roles for GKE node pool ──────────────────────────────

resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# Required to pull images from Artifact Registry
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# Required to pull images from GCS-backed Container Registry (if still in use)
resource "google_project_iam_member" "storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# ==============================================================================
# Workload Identity — per-application binding pattern
# ==============================================================================
# Do NOT add application-specific IAM roles to the node SA.
# Instead, create a dedicated GCP SA per application and bind it via
# Workload Identity:
#
#   1. Create an app-specific GCP SA:
#      resource "google_service_account" "my_app" { ... }
#
#   2. Grant it the Workload Identity User role, scoped to the K8s SA:
#      resource "google_service_account_iam_member" "workload_identity_binding" {
#        service_account_id = google_service_account.my_app.name
#        role               = "roles/iam.workloadIdentityUser"
#        member             = "serviceAccount:${var.project_id}.svc.id.goog[NAMESPACE/KSA_NAME]"
#      }
#
#   3. Annotate the K8s ServiceAccount:
#      kubectl annotate serviceaccount KSA_NAME \
#        --namespace NAMESPACE \
#        iam.gke.io/gcp-service-account=my-app-sa@PROJECT.iam.gserviceaccount.com
# ==============================================================================
