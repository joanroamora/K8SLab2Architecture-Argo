#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "DESTROY" ]]; then
  echo "Refusing to destroy. Run: scripts/destroy-dev.sh DESTROY" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/use-local-gcp.sh"
cd "$ROOT_DIR"

STATE_BUCKET="${TF_STATE_BUCKET:-$GCP_PROJECT_ID-k8s-internals-sandbox-tfstate}"
STATE_PREFIX="${TF_STATE_PREFIX:-dev}"
STATE_LOCATION="${TF_STATE_LOCATION:-US-CENTRAL1}"

ensure_state_bucket() {
  if ! gcloud storage buckets describe "gs://$STATE_BUCKET" >/dev/null 2>&1; then
    gcloud storage buckets create "gs://$STATE_BUCKET" \
      --project "$GCP_PROJECT_ID" \
      --location "$STATE_LOCATION" \
      --uniform-bucket-level-access
  fi
  gcloud storage buckets update "gs://$STATE_BUCKET" --public-access-prevention >/dev/null
}

ensure_state_bucket
terraform -chdir=terraform/environments/dev init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="prefix=$STATE_PREFIX"
terraform -chdir=terraform/environments/dev destroy -auto-approve

gcloud storage rm --recursive "gs://$STATE_BUCKET" >/dev/null 2>&1 || true

echo "Terraform destroy completed and Terraform state bucket removed: gs://$STATE_BUCKET"
