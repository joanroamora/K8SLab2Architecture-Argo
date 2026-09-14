# Chaos and Reverse Engineering Lab

Ejecuta los comandos de Kubernetes desde el master salvo que el paso indique worker.

## 1. Inspeccionar etcd directamente

SSH al master:

```bash
gcloud compute ssh k8s-internals-sandbox-master --zone us-central1-a --project bitcitychamp-project
```

Crear objetos de prueba:

```bash
kubectl create namespace internals-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl -n internals-lab create secret generic demo-secret --from-literal=password=super-secret
kubectl -n internals-lab run demo-pod --image=nginxinc/nginx-unprivileged:1.27-alpine --restart=Never
```

Leer llaves crudas de etcd con mTLS:

```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/internals-lab/demo-secret -w=json

sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/pods/internals-lab/demo-pod -w=json
```

## 2. Static Pods y caída del scheduler

```bash
sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/kube-scheduler.yaml
kubectl -n internals-lab create deployment pending-demo --image=nginxinc/nginx-unprivileged:1.27-alpine --replicas=1
kubectl -n internals-lab get pods -w
```

Qué deberías ver:

- kube-apiserver sigue aceptando el Deployment.
- controller-manager crea ReplicaSet y Pod.
- el Pod queda `Pending` porque no hay scheduler.
- la UI marca el scheduler en rojo/warning.

Restaurar:

```bash
sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/kube-scheduler.yaml
kubectl -n internals-lab get pods -w
```

## 3. Kubelet vs Node Lifecycle Controller

En el worker:

```bash
gcloud compute ssh k8s-internals-sandbox-worker --zone us-central1-a --project bitcitychamp-project
sudo systemctl stop kubelet
```

Desde el master:

```bash
kubectl get nodes -w
kubectl get pods -A -o wide
```

Qué deberías ver:

- el worker pasa a `NotReady` después del timeout.
- kube-proxy y workloads del worker dejan de reportar estado fresco.
- controller-manager marca la salud del nodo por heartbeats perdidos.
- la UI marca el data plane en warning/red.

Restaurar en el worker:

```bash
sudo systemctl start kubelet
```

## 4. kube-proxy e iptables

En el worker:

```bash
sudo iptables -t nat -L KUBE-SERVICES -n -v
sudo iptables -t nat -L KUBE-NODEPORTS -n -v
sudo iptables -t nat -S | grep KUBE
```

Observa cómo kube-proxy programa Services y NodePorts en cadenas NAT del kernel.

## Limpieza de objetos del lab

```bash
kubectl delete namespace internals-lab --ignore-not-found
```
