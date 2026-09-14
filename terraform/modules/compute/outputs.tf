output "master_name" { value = google_compute_instance.master.name }
output "worker_name" { value = google_compute_instance.worker.name }
output "master_external_ip" { value = google_compute_instance.master.network_interface[0].access_config[0].nat_ip }
output "worker_external_ip" { value = google_compute_instance.worker.network_interface[0].access_config[0].nat_ip }
output "master_internal_ip" { value = google_compute_instance.master.network_interface[0].network_ip }
output "worker_internal_ip" { value = google_compute_instance.worker.network_interface[0].network_ip }
