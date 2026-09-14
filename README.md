# k8s-internals-sandbox

Laboratorio de Kubernetes Internals sobre Google Cloud Platform usando Compute Engine, Terraform, kubeadm y Argo CD. No usa GKE: el control plane y el data plane viven en VMs Ubuntu 22.04 para que puedas romper, inspeccionar y reparar los componentes reales.

## Objetivo

Aprender cómo se comportan kube-apiserver, etcd, kube-scheduler, kube-controller-manager, kubelet, kube-proxy, CNI e iptables en un cluster real. El diseño prioriza visibilidad total y destrucción limpia para no dejar recursos cobrando.

## Arquitectura

- 1 VM control plane: `e2-standard-2`, Ubuntu 22.04, disco SSD persistente de 30 GB, `auto_delete = true`.
- 1 VM worker: `e2-medium` por defecto, Ubuntu 22.04, disco SSD persistente de 30 GB, `auto_delete = true`.
- VPC custom sin subredes automáticas.
- Firewall explícito para SSH, Kubernetes API, kubelet, etcd, Flannel VXLAN e intervalo NodePort.
- kubeadm + containerd + Flannel.
- Argo CD expuesto en `https://<MASTER_IP>:30443`.
- K8s Architecture Inspector expuesto en `http://<MASTER_IP>:30080`.
- Bucket GCS temporal y privado para bootstrap, con `force_destroy = true` y lifecycle de limpieza.

## Estructura

```text
terraform/
  environments/dev/
  modules/vpc/
  modules/compute/
kubernetes/
  inspector/
  argocd/
  demo/
docs/
scripts/
.github/workflows/
```

## Uso local sin instalar nada global

Este repo espera que uses herramientas ya presentes en la máquina. La configuración de GCP queda dentro del directorio del proyecto mediante `.gcloud/`, `.secrets/` y `.env.local`, todos ignorados por Git.

```bash
cd /home/joanr/agentic-platforms/GCP/K8SLab2Architecture1
source scripts/use-local-gcp.sh
scripts/doctor.sh
```

## Plan y apply

Argo CD clona la revision definida por `git_revision`. Publica esa revision antes del apply para que el Application de ejemplo encuentre `kubernetes/demo`:

```bash
git add .
git commit -m "feat: add k8s internals sandbox lab"
git push origin feature1architecture
```

Genera y revisa el plan. Este paso puede crear unicamente el bucket privado de estado de Terraform si aun no existe; no crea VMs, VPC ni cluster.

```bash
cd /home/joanr/agentic-platforms/GCP/K8SLab2Architecture1
source scripts/use-local-gcp.sh
scripts/plan-dev.sh
```

Despues del review explicito, aplica exactamente el archivo de plan guardado:

```bash
scripts/apply-dev.sh
```

`scripts/deploy-dev.sh` conserva el atajo para ejecutar ambas fases consecutivamente.

El bootstrap valida Flannel, el rollout de Argo CD, el NodePort `30443`, el rollout del Inspector y que `sandbox-demo` quede `Synced` y `Healthy`. Si alguno falla, el startup script termina con error visible en `/var/log/k8s-internals-master-init.log`.

## Destruir todo

El destroy está diseñado para eliminar el 100% de recursos administrados por Terraform: VMs, discos de boot, firewall, VPC, bucket temporal, IAM del lab y el bucket GCS usado para estado remoto de Terraform.

```bash
scripts/destroy-dev.sh DESTROY
```

El script exige escribir `DESTROY`, inicializa Terraform con el backend GCS correcto, ejecuta `destroy` y luego borra el bucket de estado.

## SSH

```bash
gcloud compute ssh k8s-internals-sandbox-master \
  --zone us-central1-a \
  --project bitcitychamp-project

gcloud compute ssh k8s-internals-sandbox-worker \
  --zone us-central1-a \
  --project bitcitychamp-project
```

## Accesos

```text
Inspector: http://<MASTER_IP>:30080
Argo CD:   https://<MASTER_IP>:30443
```

Contraseña inicial de Argo CD:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

## Guías

- [Arquitectura](docs/ARCHITECTURE.md)
- [Operación](docs/OPERATIONS.md)
- [Laboratorio de caos e ingeniería inversa](docs/CHAOS_LAB.md)
- [Política de destrucción limpia](docs/DESTROY.md)

## Nota de seguridad

Nunca subas `.secrets/`, `.gcloud/`, `.env.local`, `terraform.tfstate` ni llaves privadas. La service account usada para pruebas debe rotarse si fue compartida por chat, terminal o logs.
