#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_BUCKET="${bootstrap_bucket}"
MASTER_INTERNAL_IP="${master_internal_ip}"
WORKER_INTERNAL_IP="${worker_internal_ip}"
MASTER_NODE_NAME="${master_node_name}"
WORKER_NODE_NAME="${worker_node_name}"
POD_CIDR="${pod_cidr}"
KUBERNETES_REPO_MINOR="${kubernetes_repo_minor}"
FLANNEL_MANIFEST_URL="${flannel_manifest_url}"
ARGOCD_INSTALL_URL="${argocd_install_url}"
ANSIBLE_DIR="/opt/k8s-internals/ansible"
SSH_DIR="/opt/k8s-internals/ssh"
LOG_FILE="/var/log/k8s-internals-ansible-controller-init.log"

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

gcs_put() {
  local src="$1"
  local object="$2"
  local token
  local encoded_object
  token="$(metadata_token)"
  encoded_object="$(urlencode "$object")"
  curl -sf -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: text/plain" \
    --data-binary "@$src" \
    "https://storage.googleapis.com/upload/storage/v1/b/$BOOTSTRAP_BUCKET/o?uploadType=media&name=$encoded_object"
}

retry() {
  local attempts="$1"
  shift
  local delay=10
  local i
  for i in $(seq 1 "$attempts"); do
    if "$@"; then
      return 0
    fi
    echo "Retry $i/$attempts failed: $*"
    sleep "$delay"
  done
  return 1
}

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ansible ca-certificates curl openssh-client python3

install -d -m 700 "$SSH_DIR"
if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
  ssh-keygen -q -t ed25519 -N "" -f "$SSH_DIR/id_ed25519"
fi
chmod 600 "$SSH_DIR/id_ed25519"
retry 12 gcs_put "$SSH_DIR/id_ed25519.pub" ansible/controller.pub

install -d -m 755 "$ANSIBLE_DIR/manifests"
retry 12 gcs_get ansible/site.yml "$ANSIBLE_DIR/site.yml"
retry 12 gcs_get manifests/inspector.yaml "$ANSIBLE_DIR/manifests/inspector.yaml"
retry 12 gcs_get manifests/argocd-server-nodeport.yaml "$ANSIBLE_DIR/manifests/argocd-server-nodeport.yaml"
retry 12 gcs_get manifests/argocd-application.yaml "$ANSIBLE_DIR/manifests/argocd-application.yaml"

cat >"$ANSIBLE_DIR/inventory.ini" <<INVENTORY
[control_plane]
$MASTER_NODE_NAME ansible_host=$MASTER_INTERNAL_IP

[workers]
$WORKER_NODE_NAME ansible_host=$WORKER_INTERNAL_IP

[k8s_nodes:children]
control_plane
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$SSH_DIR/id_ed25519
ansible_python_interpreter=/usr/bin/python3
INVENTORY

cat >"$ANSIBLE_DIR/run-ansible.sh" <<RUNNER
#!/usr/bin/env bash
set -euo pipefail
export ANSIBLE_HOST_KEY_CHECKING=False
exec ansible-playbook -i $ANSIBLE_DIR/inventory.ini $ANSIBLE_DIR/site.yml \\
  -e "pod_cidr=$POD_CIDR kubernetes_repo_minor=$KUBERNETES_REPO_MINOR flannel_manifest_url=$FLANNEL_MANIFEST_URL argocd_install_url=$ARGOCD_INSTALL_URL worker_node_name=$WORKER_NODE_NAME" "\$@"
RUNNER
chmod 700 "$ANSIBLE_DIR/run-ansible.sh"

for _ in $(seq 1 180); do
  if ANSIBLE_HOST_KEY_CHECKING=False ansible -i "$ANSIBLE_DIR/inventory.ini" k8s_nodes -m ping; then
    break
  fi
  echo "Waiting for master and worker SSH bootstrap."
  sleep 10
done

ANSIBLE_HOST_KEY_CHECKING=False "$ANSIBLE_DIR/run-ansible.sh"

echo "Ansible controller completed. Re-run with: sudo $ANSIBLE_DIR/run-ansible.sh"
