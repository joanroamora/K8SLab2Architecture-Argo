#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_BUCKET="${bootstrap_bucket}"
NODE_ROLE="${node_role}"
LOG_FILE="/var/log/k8s-internals-$NODE_ROLE-bootstrap.log"

exec > >(tee -a "$LOG_FILE") 2>&1

urlencode() {
  python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

metadata_token() {
  curl -sf -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
}

gcs_get() {
  local object="$1"
  local dst="$2"
  local token
  local encoded_object
  token="$(metadata_token)"
  encoded_object="$(urlencode "$object")"
  curl -sf \
    -H "Authorization: Bearer $token" \
    "https://storage.googleapis.com/storage/v1/b/$BOOTSTRAP_BUCKET/o/$encoded_object?alt=media" \
    -o "$dst"
}

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl openssh-server python3

install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
touch /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

for _ in $(seq 1 180); do
  if gcs_get ansible/controller.pub /tmp/ansible-controller.pub; then
    if ! grep -qxF "$(cat /tmp/ansible-controller.pub)" /home/ubuntu/.ssh/authorized_keys; then
      cat /tmp/ansible-controller.pub >>/home/ubuntu/.ssh/authorized_keys
    fi
    chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
    echo "$NODE_ROLE is ready for Ansible over the private VPC."
    exit 0
  fi
  echo "Waiting for ansible/controller.pub in gs://$BOOTSTRAP_BUCKET"
  sleep 10
done

echo "Timed out waiting for the Ansible controller public key." >&2
exit 1
