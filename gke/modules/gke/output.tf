output "cluster_name" {
  value = "${google_container_cluster.main.name}"
}

output "cluster_identifier" {
  value = "${google_container_cluster.main.name}@${var.project}.${var.zone}"
}
