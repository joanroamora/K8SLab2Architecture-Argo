resource "google_compute_network" "this" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  name                     = "${var.name_prefix}-subnet"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = var.node_tags
}

resource "google_compute_firewall" "kube_api" {
  name    = "${var.name_prefix}-allow-kube-api"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = var.node_tags
}

resource "google_compute_firewall" "nodeports" {
  name    = "${var.name_prefix}-allow-nodeports"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = var.admin_cidrs
  target_tags   = var.node_tags
}

resource "google_compute_firewall" "internal_kubernetes" {
  name    = "${var.name_prefix}-allow-internal-kubernetes"
  network = google_compute_network.this.name

  allow {
    protocol = "tcp"
    ports    = ["6443", "10250", "10257", "10259", "2379-2380"]
  }

  source_ranges = [var.subnet_cidr, var.pod_cidr]
  target_tags   = var.node_tags
}

resource "google_compute_firewall" "internal_cni" {
  name    = "${var.name_prefix}-allow-internal-cni"
  network = google_compute_network.this.name

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }

  source_ranges = [var.subnet_cidr, var.pod_cidr]
  target_tags   = var.node_tags
}

resource "google_compute_firewall" "flannel_vxlan" {
  name    = "${var.name_prefix}-allow-flannel-vxlan"
  network = google_compute_network.this.name

  allow {
    protocol = "udp"
    ports    = ["8472"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = var.node_tags
}
