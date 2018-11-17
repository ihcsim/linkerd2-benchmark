variable "project" {}
variable "region" {}

variable "subnet_primary_ip_cidr_range" {
  default = "10.0.0.0/22"
}

variable "subnet_secondary_ip_range_pods" {
  type = "map"
  default = {
    name = "pods-range"
    cidr = "10.2.0.0/16"
  }
}

variable "subnet_secondary_ip_range_services" {
  type = "map"
  default = {
    name = "services-range"
    cidr = "172.16.0.0/20"
  }
}
