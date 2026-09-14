#!/usr/bin/env bash
set -euo pipefail

DISCOVERED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_WSL_ROOT="${K8S_LAB_LOCAL_ROOT:-/home/joanr/agentic-platforms/GCP/K8SLab2Architecture1}"

# The WSLg mount is read-only for gcloud's SQLite state. Prefer the writable
# Linux path when it contains this repository, while retaining an override.
if [[ -d "$LOCAL_WSL_ROOT/.secrets" ]]; then
  ROOT_DIR="$LOCAL_WSL_ROOT"
else
  ROOT_DIR="$DISCOVERED_ROOT"
fi

export GCP_PROJECT_ID="bitcitychamp-project"
export GOOGLE_CLOUD_PROJECT="$GCP_PROJECT_ID"
export CLOUDSDK_CONFIG="$ROOT_DIR/.gcloud"
export GOOGLE_APPLICATION_CREDENTIALS="$ROOT_DIR/.secrets/gcp-sa-key.json"

if [[ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  echo "Missing local GCP key: $GOOGLE_APPLICATION_CREDENTIALS" >&2
  return 1 2>/dev/null || exit 1
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ "$#" -gt 0 ]]; then
    exec "$@"
  fi

  echo "Local GCP environment ready for $GCP_PROJECT_ID"
  echo "To keep these exports in your shell, run: source scripts/use-local-gcp.sh"
fi
