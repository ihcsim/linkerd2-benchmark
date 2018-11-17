variable "project" {}
variable "zone" {}
variable "gke_version" {}
variable "gcp_user" {}

variable "network" {}
variable "subnetwork" {}
variable "service_account" {}

variable "cluster_secondary_range_name" {}
variable "services_secondary_range_name" {}

variable "master_ipv4_cidr_block" {
  default = "172.31.0.0/28"
}

variable "system_pool" {
  default = {
    name = "system"
    initial_node_size = "6"
    machine_type = "n1-highcpu-2"
  }
}

variable "worker_pool" {
  default = {
    initial_node_size = "1"
    machine_type = "n1-highcpu-2"
  }
}

variable "node_auto_repair" {
  default = "true"
}
variable "node_auto_upgrade" {
  default = "false"
}

variable "disk_size_gb" {
  default = "8"
}

variable "disk_type" {
  default = "pd-standard"
}

variable "image_type" {
  default = "COS"
}

variable "machine_type_default" {
  default = ""
}

variable "machine_type_worker" {
  default = "n1-standard-1"
}
