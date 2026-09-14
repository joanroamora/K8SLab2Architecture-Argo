# Operations

## Local Environment

```bash
cd /home/joanr/agentic-platforms/GCP/K8SLab2Architecture1
source scripts/use-local-gcp.sh
scripts/doctor.sh
```

## Plan and Apply

```bash
git push origin feature1architecture
scripts/plan-dev.sh
scripts/apply-dev.sh
```

El Application de Argo CD apunta a `git_repo_url` y `git_revision` de `terraform.tfvars`; esa revision debe existir en remoto antes del apply.

## Bootstrap Validation

```bash
gcloud compute ssh k8s-internals-sandbox-master --zone us-central1-a --project bitcitychamp-project -- \
  "sudo tail -n 120 /var/log/k8s-internals-master-init.log"

kubectl -n argocd get application sandbox-demo
kubectl -n argocd get service argocd-server -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}'; echo
curl -fsS http://<MASTER_IP>:30080/api/status
```

El Application debe indicar `Synced` y `Healthy`; el NodePort debe imprimir `30443`. El endpoint del Inspector devuelve el estado que esta leyendo de la API real del cluster.

## Watch Bootstrap Logs

```bash
gcloud compute ssh k8s-internals-sandbox-master --zone us-central1-a --project bitcitychamp-project -- \
  "sudo tail -f /var/log/k8s-internals-master-init.log"

gcloud compute ssh k8s-internals-sandbox-worker --zone us-central1-a --project bitcitychamp-project -- \
  "sudo tail -f /var/log/k8s-internals-worker-init.log"
```

## Cluster State

```bash
gcloud compute ssh k8s-internals-sandbox-master --zone us-central1-a --project bitcitychamp-project
kubectl get nodes -o wide
kubectl get pods -A
```

## Argo CD Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

## Destroy

```bash
scripts/destroy-dev.sh DESTROY
```
