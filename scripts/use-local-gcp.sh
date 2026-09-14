#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
