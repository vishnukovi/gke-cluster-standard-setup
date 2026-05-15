#!/usr/bin/env bash
# ==============================================================================
# setup.sh — Bootstrap script for first-time GKE cluster provisioning
#
# What it does:
#   1. Enables required GCP APIs
#   2. Creates the GCS bucket for Terraform remote state
#   3. Creates the CI/CD service account with Workload Identity Federation
#   4. Runs terraform init + apply for the target environment
#
# Usage:
#   ./scripts/setup.sh dev   your-gcp-project-id
#   ./scripts/setup.sh prod  your-gcp-project-id
# ==============================================================================

set -euo pipefail

ENVIRONMENT="${1:-}"
PROJECT_ID="${2:-}"
REGION="${REGION:-us-central1}"
STATE_BUCKET="${PROJECT_ID}-tfstate"
GITHUB_REPO="${GITHUB_REPO:-YOUR_ORG/YOUR_REPO}"  # e.g. acme/platform-infra

# ── Validate inputs ───────────────────────────────────────────────────────────
if [[ -z "${ENVIRONMENT}" || -z "${PROJECT_ID}" ]]; then
  echo "Usage: $0 <environment> <project_id>"
  echo "       environment: dev | prod"
  exit 1
fi

if [[ ! "${ENVIRONMENT}" =~ ^(dev|prod)$ ]]; then
  echo "ERROR: environment must be 'dev' or 'prod'"
  exit 1
fi

echo "=========================================="
echo "  Environment : ${ENVIRONMENT}"
echo "  Project     : ${PROJECT_ID}"
echo "  Region      : ${REGION}"
echo "  State Bucket: ${STATE_BUCKET}"
echo "=========================================="
read -r -p "Continue? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || exit 0

# ── 1. Enable required APIs ───────────────────────────────────────────────────
echo ""
echo ">>> Enabling required GCP APIs..."
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  artifactregistry.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  dns.googleapis.com \
  binaryauthorization.googleapis.com \
  --project="${PROJECT_ID}"

echo "    APIs enabled."

# ── 2. Create GCS state bucket ────────────────────────────────────────────────
echo ""
echo ">>> Creating Terraform state bucket: gs://${STATE_BUCKET}"

if gsutil ls "gs://${STATE_BUCKET}" &>/dev/null; then
  echo "    Bucket already exists, skipping creation."
else
  gsutil mb -p "${PROJECT_ID}" -l "${REGION}" "gs://${STATE_BUCKET}"
  gsutil versioning set on "gs://${STATE_BUCKET}"
  gsutil ubla set on "gs://${STATE_BUCKET}"       # uniform bucket-level access
  gsutil lifecycle set /dev/stdin "gs://${STATE_BUCKET}" <<'EOF'
{
  "rule": [{
    "action": {"type": "Delete"},
    "condition": {"numNewerVersions": 10, "isLive": false}
  }]
}
EOF
  echo "    Bucket created with versioning and lifecycle policy."
fi

# ── 3. Create Terraform CI/CD service account ─────────────────────────────────
echo ""
SA_NAME="terraform-cicd"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo ">>> Creating CI/CD service account: ${SA_EMAIL}"

if gcloud iam service-accounts describe "${SA_EMAIL}" --project="${PROJECT_ID}" &>/dev/null; then
  echo "    Service account already exists, skipping creation."
else
  gcloud iam service-accounts create "${SA_NAME}" \
    --display-name="Terraform CI/CD" \
    --description="Used by GitHub Actions to run Terraform" \
    --project="${PROJECT_ID}"
fi

# Grant required roles to the CI/CD SA
ROLES=(
  "roles/container.admin"
  "roles/compute.networkAdmin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountUser"
  "roles/storage.admin"
  "roles/resourcemanager.projectIamAdmin"
  "roles/artifactregistry.admin"
  "roles/binaryauthorization.attestorsAdmin"
)

for ROLE in "${ROLES[@]}"; do
  echo "    Granting ${ROLE}..."
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}" \
    --quiet
done

# ── 4. Set up Workload Identity Federation (keyless auth for GitHub Actions) ──
echo ""
echo ">>> Setting up Workload Identity Federation for GitHub Actions..."
POOL_ID="github-pool"
PROVIDER_ID="github-provider"

# Create WIF pool if it doesn't exist
if ! gcloud iam workload-identity-pools describe "${POOL_ID}" \
  --project="${PROJECT_ID}" --location="global" &>/dev/null; then
  gcloud iam workload-identity-pools create "${POOL_ID}" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --display-name="GitHub Actions Pool"
fi

POOL_NAME="projects/$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_ID}"

# Create OIDC provider if it doesn't exist
if ! gcloud iam workload-identity-pools providers describe "${PROVIDER_ID}" \
  --pool="${POOL_ID}" --project="${PROJECT_ID}" --location="global" &>/dev/null; then
  gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="${POOL_ID}" \
    --display-name="GitHub Actions Provider" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'"
fi

# Allow the GitHub Actions OIDC token to impersonate the CI/CD SA
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_NAME}/attribute.repository/${GITHUB_REPO}"

PROVIDER_FULL="${POOL_NAME}/providers/${PROVIDER_ID}"
echo ""
echo "======================================================================"
echo "  Workload Identity setup complete!"
echo ""
echo "  Add these to your GitHub repo Secrets/Variables:"
echo ""
echo "  Secret: GCP_WORKLOAD_IDENTITY_PROVIDER"
echo "  Value:  ${PROVIDER_FULL}"
echo ""
echo "  Secret: GCP_SERVICE_ACCOUNT"
echo "  Value:  ${SA_EMAIL}"
echo ""
echo "  Variable: GCP_PROJECT_ID"
echo "  Value:    ${PROJECT_ID}"
echo "======================================================================"

# ── 5. Update backend bucket name in tfvars ───────────────────────────────────
echo ""
echo ">>> Updating backend.tf with bucket name: ${STATE_BUCKET}"
sed -i "s/YOUR_PROJECT_ID-tfstate/${STATE_BUCKET}/g" \
  "environments/${ENVIRONMENT}/backend.tf"

# ── 6. Terraform init + plan ──────────────────────────────────────────────────
echo ""
echo ">>> Running terraform init for '${ENVIRONMENT}'..."
cd "environments/${ENVIRONMENT}"
terraform init -input=false

echo ""
echo ">>> Running terraform plan for '${ENVIRONMENT}'..."
terraform plan -var="project_id=${PROJECT_ID}" -input=false

echo ""
echo "======================================================================"
echo "  Setup complete! Review the plan above, then run:"
echo ""
echo "  cd environments/${ENVIRONMENT}"
echo "  terraform apply -var=\"project_id=${PROJECT_ID}\""
echo "======================================================================"
