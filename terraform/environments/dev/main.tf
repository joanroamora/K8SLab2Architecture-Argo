terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  name_prefix = var.name_prefix
  root_path   = abspath("${path.module}/../../..")

  bootstrap_objects = {
    "manifests/inspector.yaml"              = file("${local.root_path}/kubernetes/inspector/inspector.yaml")
    "manifests/argocd-server-nodeport.yaml" = file("${local.root_path}/kubernetes/argocd/argocd-server-nodeport.yaml")
    "manifests/argocd-application.yaml" = templatefile("${local.root_path}/kubernetes/argocd/application.yaml.tpl", {
      repo_url = var.git_repo_url
      revision = var.git_revision
    })
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "bootstrap" {
  name                        = "${var.project_id}-${local.name_prefix}-bootstrap-${random_id.suffix.hex}"
  location                    = upper(var.region)
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = var.labels

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_object" "bootstrap_manifests" {
  for_each = local.bootstrap_objects

  bucket       = google_storage_bucket.bootstrap.name
  name         = each.key
  content      = each.value
  content_type = "text/yaml"
}

resource "google_service_account" "nodes" {
  account_id   = "${local.name_prefix}-nodes"
  display_name = "kubeadm node bootstrap service account"
}

resource "google_storage_bucket_iam_member" "node_bootstrap_rw" {
  bucket = google_storage_bucket.bootstrap.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.nodes.email}"
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix = local.name_prefix
  region      = var.region
  subnet_cidr = var.subnet_cidr
  pod_cidr    = var.pod_cidr
  admin_cidrs = var.admin_cidrs
  node_tags   = ["${local.name_prefix}-node"]
  labels      = var.labels
}

module "compute" {
  source = "../../modules/compute"

  depends_on = [
    google_storage_bucket_iam_member.node_bootstrap_rw,
    google_storage_bucket_object.bootstrap_manifests
  ]

  project_id            = var.project_id
  name_prefix           = local.name_prefix
  zone                  = var.zone
  network_self_link     = module.vpc.network_self_link
  subnetwork_self_link  = module.vpc.subnetwork_self_link
  node_tags             = ["${local.name_prefix}-node"]
  service_account_email = google_service_account.nodes.email
  bootstrap_bucket      = google_storage_bucket.bootstrap.name
  pod_cidr              = var.pod_cidr
  kubernetes_repo_minor = var.kubernetes_repo_minor
  flannel_manifest_url  = var.flannel_manifest_url
  argocd_install_url    = var.argocd_install_url
  master_machine_type   = var.master_machine_type
  worker_machine_type   = var.worker_machine_type
  boot_disk_size_gb     = var.boot_disk_size_gb
  boot_disk_type        = var.boot_disk_type
  labels                = var.labels
}
