output "vpc" {
  value = "${google_compute_network.main.name}"
}

output "subnetwork" {
  value = "${google_compute_subnetwork.main.name}"
}

output "cluster_secondary_range_name" {
  value = "pods-range"
}

output "services_secondary_range_name" {
  value = "services-range"
}
