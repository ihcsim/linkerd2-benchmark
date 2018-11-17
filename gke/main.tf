provider "google" {
  version = "~>1.17"
  project = "${var.project}"
  region = "${var.region}"
}

provider "null" {
  version = "~> 1.0"
}

terraform {
  backend "gcs" {
    bucket = "linkerd2-benchmark"
    project = "linkerd2-benchmark"
    region = "us-west1"
  }
}

module "network" {
  source = "./modules/network"

  project = "${var.project}"
  region = "${var.region}"
}

module "k8s" {
  source = "./modules/gke"

  project = "${var.project}"
  zone = "${var.gke_zone}"
  gke_version = "${var.gke_version}"
  service_account = "${var.gke_service_account}"
  gcp_user = "${var.gcp_user}"

  network = "${module.network.vpc}"
  subnetwork = "${module.network.subnetwork}"
  cluster_secondary_range_name = "${module.network.cluster_secondary_range_name}"
  services_secondary_range_name = "${module.network.services_secondary_range_name}"
}

#module "dns" {
  #source = "./modules/dns"

  #zone = "${var.gke_zone}"
  #cluster_name = "${module.k8s.cluster_name}"
  #cluster_identifier = "${module.k8s.cluster_identifier}"
  #external_dns_version = "${var.external_dns_version}"
#}
