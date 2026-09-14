#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/use-local-gcp.sh"
cd "$ROOT_DIR"

STATE_BUCKET="${TF_STATE_BUCKET:-$GCP_PROJECT_ID-k8s-internals-sandbox-tfstate}"
STATE_PREFIX="${TF_STATE_PREFIX:-dev}"
STATE_LOCATION="${TF_STATE_LOCATION:-US-CENTRAL1}"
TERRAFORM_DIR="$ROOT_DIR/terraform/environments/dev"
PLAN_FILE="${TF_PLAN_FILE:-$TERRAFORM_DIR/tfplan}"

ensure_state_bucket() {
  if ! gcloud storage buckets describe "gs://$STATE_BUCKET" >/dev/null 2>&1; then
    gcloud storage buckets create "gs://$STATE_BUCKET" \
      --project "$GCP_PROJECT_ID" \
      --location "$STATE_LOCATION" \
      --uniform-bucket-level-access
  fi
  gcloud storage buckets update "gs://$STATE_BUCKET" --public-access-prevention=enforced >/dev/null
}

if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
  cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/terraform.tfvars"
fi

ensure_state_bucket
terraform -chdir="$TERRAFORM_DIR" init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="prefix=$STATE_PREFIX"
terraform -chdir="$TERRAFORM_DIR" plan -out="$PLAN_FILE"

echo "Plan saved to $PLAN_FILE"
echo "Review it, publish git_revision to the remote repository, then run scripts/apply-dev.sh"
