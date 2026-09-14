variable "project_id" {
  description = "GCP project id."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Resource name prefix. Keep stable so destroy can track every resource through state."
  type        = string
  default     = "k8s-internals-sandbox"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR for VMs."
  type        = string
  default     = "10.10.0.0/24"
}

variable "pod_cidr" {
  description = "Kubernetes pod CIDR used by kubeadm and Flannel."
  type        = string
  default     = "10.244.0.0/16"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to access SSH, Kubernetes API and NodePorts. Restrict to your public IP /32 when possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "master_machine_type" {
  description = "Control plane VM size."
  type        = string
  default     = "e2-standard-2"
}

variable "worker_machine_type" {
  description = "Worker VM size."
  type        = string
  default     = "e2-medium"
}

variable "controller_machine_type" {
  description = "Ephemeral Ansible controller VM size."
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size for both nodes."
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "pd-ssd"
}

variable "controller_boot_disk_size_gb" {
  description = "Boot disk size for the Ansible controller."
  type        = number
  default     = 20
}

variable "controller_boot_disk_type" {
  description = "Boot disk type for the Ansible controller."
  type        = string
  default     = "pd-balanced"
}

variable "kubernetes_repo_minor" {
  description = "Kubernetes apt repository minor line from pkgs.k8s.io."
  type        = string
  default     = "v1.30"
}

variable "flannel_manifest_url" {
  description = "Pinned Flannel manifest used by kubeadm bootstrap."
  type        = string
  default     = "https://github.com/flannel-io/flannel/releases/download/v0.28.8/kube-flannel.yml"
}

variable "argocd_install_url" {
  description = "Pinned Argo CD upstream install manifest."
  type        = string
  default     = "https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml"
}

variable "git_repo_url" {
  description = "Git repository URL consumed by the sample Argo CD Application."
  type        = string
  default     = "https://github.com/joanroamora/K8SLab2Architecture-Argo.git"
}

variable "git_revision" {
  description = "Git revision for Argo CD sample Application."
  type        = string
  default     = "feature1architecture"
}

variable "labels" {
  description = "Common GCP labels."
  type        = map(string)
  default = {
    project = "k8s-internals-sandbox"
    owner   = "terraform"
    ttl     = "lab"
  }
}
