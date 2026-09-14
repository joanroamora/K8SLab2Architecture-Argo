# Architecture

`k8s-internals-sandbox` crea un cluster kubeadm mínimo sobre Compute Engine puro.

## Control Plane

La VM master ejecuta kubelet y los static pods de kubeadm:

- kube-apiserver
- etcd
- kube-scheduler
- kube-controller-manager

Los manifests viven en `/etc/kubernetes/manifests`. Mover un archivo fuera de ese directorio simula la caída de un componente sin borrar la VM.

## Data Plane

La VM worker ejecuta:

- kubelet
- containerd
- kube-proxy
- Flannel CNI
- workloads de usuario

Flannel usa `10.244.0.0/16` y VXLAN UDP 8472 entre nodos.

## Bootstrap Flow

1. Terraform crea VPC, firewall, bucket privado de bootstrap, service account de nodos y dos VMs.
2. El master instala containerd, kubeadm, kubelet y kubectl.
3. El master ejecuta `kubeadm init --pod-network-cidr=10.244.0.0/16`.
4. El master instala la version fijada de Flannel y espera que su DaemonSet este listo.
5. El master escribe el `kubeadm join` en el bucket privado.
6. El worker consulta el bucket, descarga el join command y se une al cluster.
7. El master instala Argo CD desde un manifiesto versionado, aplica un strategic patch que fija HTTPS en NodePort `30443` y espera el rollout.
8. El master instala K8s Architecture Inspector, espera su rollout y verifica que el Application `sandbox-demo` de Argo CD quede `Synced` y `Healthy`.

## Inspector Data Sources

El Inspector no usa datos simulados. Su ServiceAccount de solo lectura consulta la API del cluster para listar Pods, Nodes y Leases de `kube-node-lease`, y consulta `/livez` del API server. Por eso puede distinguir los static Pods del control plane, el DaemonSet de Flannel en `kube-flannel`, kube-proxy, la condicion `Ready` de cada nodo, los heartbeats que renueva kubelet y Pods pendientes sin nodo asignado.

Sus probes usan un endpoint local separado de `/api/status`. Durante una caida intencional del API server, el contenedor sigue Ready y la UI puede mostrar la degradacion en vez de reiniciarse.

## Zero Residue Model

Terraform administra todos los recursos cloud:

- VPC y subred
- reglas de firewall
- bucket de bootstrap con `force_destroy = true`
- binding IAM del bucket
- service account de nodos
- VMs master y worker
- boot disks con `auto_delete = true`
- IPs externas efímeras atadas a las VMs

No se crean IPs estáticas, snapshots, discos desacoplados, NAT gateways, load balancers ni recursos GKE.
