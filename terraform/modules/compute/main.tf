data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "master" {
  name         = "${var.name_prefix}-master"
  machine_type = var.master_machine_type
  zone         = var.zone
  tags         = concat(var.node_tags, ["${var.name_prefix}-control-plane"])
  labels       = var.labels

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnetwork_self_link
    access_config {}
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    block-project-ssh-keys = "false"
  }

  metadata_startup_script = templatefile("${path.module}/files/master-init.sh", {
    project_id            = var.project_id
    bootstrap_bucket      = var.bootstrap_bucket
    pod_cidr              = var.pod_cidr
    kubernetes_repo_minor = var.kubernetes_repo_minor
    flannel_manifest_url  = var.flannel_manifest_url
    argocd_install_url    = var.argocd_install_url
  })

  lifecycle {
    create_before_destroy = false
  }
}

resource "google_compute_instance" "worker" {
  name         = "${var.name_prefix}-worker"
  machine_type = var.worker_machine_type
  zone         = var.zone
  tags         = concat(var.node_tags, ["${var.name_prefix}-worker"])
  labels       = var.labels

  boot_disk {
    auto_delete = true
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnetwork_self_link
    access_config {}
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    block-project-ssh-keys = "false"
  }

  metadata_startup_script = templatefile("${path.module}/files/worker-init.sh", {
    project_id            = var.project_id
    bootstrap_bucket      = var.bootstrap_bucket
    kubernetes_repo_minor = var.kubernetes_repo_minor
  })

  lifecycle {
    create_before_destroy = false
  }
}
