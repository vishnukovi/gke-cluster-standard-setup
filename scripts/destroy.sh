#!/usr/bin/env bash
# ==============================================================================
# destroy.sh — Safely destroy a GKE environment
# Requires explicit environment + project confirmation before destroying.
#
# Usage:
#   ./scripts/destroy.sh dev   your-gcp-project-id
#   ./scripts/destroy.sh prod  your-gcp-project-id
# ==============================================================================

set -euo pipefail

ENVIRONMENT="${1:-}"
PROJECT_ID="${2:-}"

if [[ -z "${ENVIRONMENT}" || -z "${PROJECT_ID}" ]]; then
  echo "Usage: $0 <environment> <project_id>"
  exit 1
fi

if [[ ! "${ENVIRONMENT}" =~ ^(dev|prod)$ ]]; then
  echo "ERROR: environment must be 'dev' or 'prod'"
  exit 1
fi

echo ""
echo "⚠️  WARNING: This will DESTROY all resources in '${ENVIRONMENT}' (project: ${PROJECT_ID})."
echo ""
echo "Type the environment name to confirm: "
read -r input
if [[ "${input}" != "${ENVIRONMENT}" ]]; then
  echo "Confirmation did not match. Aborting."
  exit 1
fi

cd "environments/${ENVIRONMENT}"
terraform destroy -var="project_id=${PROJECT_ID}" -input=false
