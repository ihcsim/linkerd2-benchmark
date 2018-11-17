variable "gcp_user" {}
variable "gke_service_account" {}

variable "project" {
  default = "linkerd2-benchmark"
}

variable "region" {
  default = "us-west1"
}

variable "gke_zone" {
  default = "us-west1-a"
}

variable "gke_version" {
  default = "1.10.7-gke.6"
}
