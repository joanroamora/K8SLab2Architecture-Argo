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

## Configuration Management

Terraform crea infraestructura, pero no instala Kubernetes directamente. La VM `ansible-controller` instala Ansible dentro de GCP y orquesta el resto del laboratorio usando las IPs privadas de la VPC.

- El controller genera una clave SSH ed25519 efimera en su propio disco.
- Publica solo la clave publica en el bucket de bootstrap privado.
- Master y worker esperan esa clave y el controller los gestiona por la VPC; el acceso SSH administrativo externo sigue limitado por `admin_cidrs`.
- El controller descarga el playbook versionado desde el mismo bucket y ejecuta Ansible contra ambos nodos.
- Para reconciliar de nuevo sin instalar nada local, conecta al controller y ejecuta `sudo /opt/k8s-internals/ansible/run-ansible.sh`.

## Bootstrap Flow

1. Terraform crea VPC, firewall, bucket privado, service account, master, worker y Ansible Controller.
2. El controller instala Ansible, genera su clave efimera y espera SSH privado hacia master y worker.
3. Ansible instala containerd, kubeadm, kubelet y kubectl en ambos nodos.
4. Ansible inicializa el master y aplica la version fijada de Flannel.
5. Ansible genera el join command en el master y une el worker.
6. Ansible instala Argo CD, aplica el strategic patch que fija HTTPS en NodePort `30443` y espera el rollout.
7. Ansible instala K8s Architecture Inspector y verifica que el Application `sandbox-demo` quede `Synced` y `Healthy`.

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
- VMs master, worker y Ansible Controller
- boot disks con `auto_delete = true`
- IPs externas efímeras atadas a las VMs

No se crean IPs estáticas, snapshots, discos desacoplados, NAT gateways, load balancers ni recursos GKE.
