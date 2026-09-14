#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${project_id}"
BOOTSTRAP_BUCKET="${bootstrap_bucket}"
POD_CIDR="${pod_cidr}"
KUBERNETES_REPO_MINOR="${kubernetes_repo_minor}"
FLANNEL_MANIFEST_URL="${flannel_manifest_url}"
ARGOCD_INSTALL_URL="${argocd_install_url}"
LOG_FILE="/var/log/k8s-internals-master-init.log"

exec > >(tee -a "$LOG_FILE") 2>&1

retry() {
  local attempts="$1"
  shift
  local delay=10
  local i
  for i in $(seq 1 "$attempts"); do
    if "$@"; then
      return 0
    fi
    echo "retry $i/$attempts failed: $*"
    sleep "$delay"
  done
  return 1
}

urlencode() {
  python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

metadata_token() {
  curl -sf -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])'
}

gcs_put() {
  local src="$1"
  local object="$2"
  local token
  token="$(metadata_token)"
  curl -sf -X POST \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$src" \
    "https://storage.googleapis.com/upload/storage/v1/b/$BOOTSTRAP_BUCKET/o?uploadType=media&name=$object"
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
  DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl etcd-client
  apt-mark hold kubelet kubeadm kubectl
  systemctl enable kubelet
}

setup_kubeconfig() {
  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config
  chmod 600 /root/.kube/config

  if id ubuntu >/dev/null 2>&1; then
    mkdir -p /home/ubuntu/.kube
    cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube
    chmod 600 /home/ubuntu/.kube/config
  fi
}

install_node_prereqs

MASTER_IP="$(hostname -I | awk '{print $1}')"

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  kubeadm init \
    --apiserver-advertise-address="$MASTER_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --upload-certs
fi

setup_kubeconfig
export KUBECONFIG=/etc/kubernetes/admin.conf

retry 30 kubectl get --raw=/livez
retry 12 kubectl apply -f "$FLANNEL_MANIFEST_URL"
kubectl -n kube-flannel rollout status daemonset/kube-flannel-ds --timeout=10m

kubeadm token create --print-join-command --ttl 24h >/tmp/kubeadm-join-command.sh
chmod 600 /tmp/kubeadm-join-command.sh
retry 12 gcs_put /tmp/kubeadm-join-command.sh join-command.sh

mkdir -p /opt/k8s-internals/manifests
retry 12 gcs_get manifests/inspector.yaml /opt/k8s-internals/manifests/inspector.yaml
retry 12 gcs_get manifests/argocd-server-nodeport.yaml /opt/k8s-internals/manifests/argocd-server-nodeport.yaml
retry 12 gcs_get manifests/argocd-application.yaml /opt/k8s-internals/manifests/argocd-application.yaml

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
retry 12 kubectl apply --server-side --force-conflicts -n argocd -f "$ARGOCD_INSTALL_URL"
kubectl wait --for=condition=Established --timeout=5m crd/applications.argoproj.io
kubectl -n argocd patch service argocd-server \
  --type=strategic \
  --patch-file /opt/k8s-internals/manifests/argocd-server-nodeport.yaml
retry 12 kubectl apply -f /opt/k8s-internals/manifests/inspector.yaml

kubectl -n argocd rollout status deployment/argocd-server --timeout=15m
kubectl -n k8s-inspector rollout status deployment/k8s-inspector --timeout=15m
kubectl apply -f /opt/k8s-internals/manifests/argocd-application.yaml
kubectl -n argocd wait \
  --for=jsonpath='{.status.sync.status}'=Synced \
  application/sandbox-demo \
  --timeout=15m
kubectl -n argocd wait \
  --for=jsonpath='{.status.health.status}'=Healthy \
  application/sandbox-demo \
  --timeout=15m

ARGOCD_NODEPORT="$(kubectl -n argocd get service argocd-server -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')"
if [[ "$ARGOCD_NODEPORT" != "30443" ]]; then
  echo "Argo CD NodePort mismatch: expected 30443, got $ARGOCD_NODEPORT" >&2
  exit 1
fi

echo "Master bootstrap completed. Inspector: http://$MASTER_IP:30080 Argo CD: https://$MASTER_IP:30443"
