#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/use-local-gcp.sh"
cd "$ROOT_DIR"

STATE_BUCKET="${TF_STATE_BUCKET:-$GCP_PROJECT_ID-k8s-internals-sandbox-tfstate}"
STATE_PREFIX="${TF_STATE_PREFIX:-dev}"
TERRAFORM_DIR="$ROOT_DIR/terraform/environments/dev"
PLAN_FILE="${TF_PLAN_FILE:-$TERRAFORM_DIR/tfplan}"

if [[ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]]; then
  echo "Missing $TERRAFORM_DIR/terraform.tfvars. Run scripts/plan-dev.sh first." >&2
  exit 1
fi

if ! gcloud storage buckets describe "gs://$STATE_BUCKET" >/dev/null 2>&1; then
  echo "Missing Terraform state bucket gs://$STATE_BUCKET. Run scripts/plan-dev.sh first." >&2
  exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Missing saved plan $PLAN_FILE. Run scripts/plan-dev.sh and review the result first." >&2
  exit 1
fi

terraform -chdir="$TERRAFORM_DIR" init -reconfigure \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="prefix=$STATE_PREFIX"
terraform -chdir="$TERRAFORM_DIR" apply "$PLAN_FILE"
terraform -chdir="$TERRAFORM_DIR" output

rm -f "$PLAN_FILE"
