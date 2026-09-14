# Destroy Policy

Este repo está diseñado para que `terraform destroy -auto-approve` elimine todos los recursos GCP que crea.

## Se destruye

- VMs master y worker
- boot disks porque `auto_delete = true`
- IPs externas efímeras atadas a las VMs
- subred
- VPC
- reglas de firewall
- bucket privado de bootstrap porque `force_destroy = true`
- objetos dentro del bucket
- binding IAM del bucket
- service account de nodos
- bucket GCS de estado Terraform creado por scripts/workflows

## No se crea

- GKE
- Cloud NAT
- Load Balancer
- IP externa estática reservada
- discos persistentes desacoplados
- snapshots
- Artifact Registry

## Destroy local seguro

```bash
scripts/destroy-dev.sh DESTROY
```

## Verificación manual

```bash
gcloud compute instances list --filter="name~k8s-internals-sandbox"
gcloud compute disks list --filter="name~k8s-internals-sandbox"
gcloud compute networks list --filter="name~k8s-internals-sandbox"
gcloud compute firewall-rules list --filter="name~k8s-internals-sandbox"
gcloud storage buckets list --filter="name:k8s-internals-sandbox"
gcloud storage buckets list --filter="name:k8s-internals-sandbox-tfstate"
```
