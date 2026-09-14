#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${project_id}"
BOOTSTRAP_BUCKET="${bootstrap_bucket}"
KUBERNETES_REPO_MINOR="${kubernetes_repo_minor}"
LOG_FILE="/var/log/k8s-internals-worker-init.log"

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

install_node_prereqs() {
  swapoff -a || true
  sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

  cat >/etc/modules-load.d/k8s.conf <<MODULES
br_netfilter
overlay
MODULES
  modprobe overlay
  modprobe br_netfilter

  cat >/etc/sysctl.d/99-kubernetes-cri.conf <<SYSCTL
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL
  sysctl --system

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release containerd

  mkdir -p /etc/containerd
  containerd config default >/etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
  systemctl enable containerd

  mkdir -p /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBERNETES_REPO_MINOR/deb/Release.key" \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_REPO_MINOR/deb/ /" \
    >/etc/apt/sources.list.d/kubernetes.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  systemctl enable kubelet
}

install_node_prereqs

if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "Worker already joined; skipping kubeadm join."
  exit 0
fi

mkdir -p /opt/k8s-internals
for _ in $(seq 1 180); do
  if gcs_get join-command.sh /opt/k8s-internals/kubeadm-join-command.sh; then
    break
  fi
  echo "Waiting for kubeadm join command in gs://$BOOTSTRAP_BUCKET/join-command.sh"
  sleep 10
done

if [[ ! -s /opt/k8s-internals/kubeadm-join-command.sh ]]; then
  echo "Join command was not found in bootstrap bucket" >&2
  exit 1
fi

chmod 700 /opt/k8s-internals/kubeadm-join-command.sh
bash /opt/k8s-internals/kubeadm-join-command.sh

echo "Worker joined cluster."
