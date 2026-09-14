#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/use-local-gcp.sh"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "MISSING: $1"
    exit 1
  fi
  echo "OK: $1 -> $(command -v "$1")"
}

need gcloud
need terraform
need kubectl
need python3
need git

printf "GCP account: "
gcloud auth list --filter=status:ACTIVE --format="value(account)"
printf "GCP project: "
gcloud projects describe "$GCP_PROJECT_ID" --format="value(projectId,lifecycleState)"
