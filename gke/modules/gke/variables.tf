variable "project" {}
variable "zone" {}
variable "gke_version" {}

variable "gcp_user" {
  description = "Username of the identity used to run the gcloud command. As part of the Linkerd2 installation, this username will be assigned the cluster-admin cluster role."
}

variable "network" {}
variable "subnetwork" {}
variable "service_account" {}

variable "cluster_secondary_range_name" {}
variable "services_secondary_range_name" {}

variable "kube_system_pool" {
  default = {
    name = "kube-system"
    initial_node_count = "1"
    machine_type = "n1-standard-2"
    disk_size_gb = "20"
  }
}

variable "system_pool" {
  default = {
    initial_node_count = "1"
    machine_type = "n1-highcpu-4"
    disk_size_gb = "20"
  }
}

variable "worker_pool" {
  default = {
    initial_node_count = "1"
    machine_type = "n1-standard-1"
    disk_size_gb = "10"
  }
}

variable "node_auto_repair" {
  default = "true"
}
variable "node_auto_upgrade" {
  default = "false"
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
