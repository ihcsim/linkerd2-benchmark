resource "google_compute_network" "main" {
  name = "main"
  project = "${var.project}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "main" {
  name = "${var.region}"
  region = "${var.region}"
  project = "${var.project}"

  network = "${google_compute_network.main.self_link}"
  ip_cidr_range = "${var.subnet_primary_ip_cidr_range}"
  secondary_ip_range  = [
    {
      range_name = "${var.subnet_secondary_ip_range_services["name"]}"
      ip_cidr_range = "${var.subnet_secondary_ip_range_services["cidr"]}"
    },
    {
      range_name = "${var.subnet_secondary_ip_range_pods["name"]}"
      ip_cidr_range = "${var.subnet_secondary_ip_range_pods["cidr"]}"
    }
  ]

  private_ip_google_access = "true"
}
