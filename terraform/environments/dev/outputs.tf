output "master_external_ip" {
  description = "Control plane external IP."
  value       = module.compute.master_external_ip
}

output "worker_external_ip" {
  description = "Worker external IP."
  value       = module.compute.worker_external_ip
}

output "inspector_url" {
  description = "K8s Architecture Inspector NodePort URL."
  value       = "http://${module.compute.master_external_ip}:30080"
}

output "argocd_url" {
  description = "Argo CD NodePort URL."
  value       = "https://${module.compute.master_external_ip}:30443"
}

output "bootstrap_bucket" {
  description = "Temporary bootstrap bucket. Destroyed by terraform destroy."
  value       = google_storage_bucket.bootstrap.name
}

output "ssh_master" {
  value = "gcloud compute ssh ${module.compute.master_name} --zone ${var.zone} --project ${var.project_id}"
}

output "ssh_worker" {
  value = "gcloud compute ssh ${module.compute.worker_name} --zone ${var.zone} --project ${var.project_id}"
}
