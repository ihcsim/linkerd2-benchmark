resource "google_container_cluster" "main" {
  name = "main"
  project = "${var.project}"
  zone = "${var.zone}"

  min_master_version = "${var.gke_version}"
  node_version = "${var.gke_version}"

  master_ipv4_cidr_block = "${var.master_ipv4_cidr_block}"

  network = "${var.network}"
  subnetwork = "${var.subnetwork}"

  ip_allocation_policy {
    cluster_secondary_range_name = "${var.cluster_secondary_range_name}"
    services_secondary_range_name = "${var.services_secondary_range_name}"
  }

  master_auth {
    # disable basic auth
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = true
    }
  }

  node_pool = [{
    name = "${var.system_pool["name"]}"
    initial_node_count = "${var.system_pool["initial_node_count"]}"

    node_config {
      machine_type = "${var.system_pool["machine_type"]}"
      disk_size_gb = "${var.disk_size_gb}"
      disk_type = "${var.disk_type}"
      image_type = "${var.image_type}"
      oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
      service_account = "${var.service_account}"

      labels = {
        node_group = "${var.system_pool["name"]}"
      }
    }

    management {
      auto_repair = "${var.node_auto_repair}"
      auto_upgrade = "${var.node_auto_upgrade}"
    }
  }]

  lifecycle {
    ignore_changes = ["node_pool"]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00"
    }
  }
}

resource "google_container_node_pool" "linkerd_meshed" {
  name = "linkerd_meshed"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_size"]}"

  node_config {
    preemptible = true
    machine_type = "${var.system_pool["machine_type"]}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    # reserve for 'reserved' pods
    taint {
      key = "reserved"
      value = "true"
      effect = "NO_SCHEDULE"
    }

    labels = {
      node_group = "linkerd_meshed"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "istio_meshed" {
  name = "istio_meshed"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_size"]}"

  node_config {
    preemptible = true
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "istio_meshed"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "load_generator" {
  name = "load_generator"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_size"]}"

  node_config {
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.disk_size_gb}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "load_generator"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "null_resource" "kubeconfig" {
  triggers {
    cluster_endpoint = "${google_container_cluster.main.endpoint}"
  }

  depends_on = ["google_container_cluster.main"]

  provisioner "local-exec" {
    command = <<EOT
      set -e

      max_retries=20
      try=0
      while : ; do
        status=`gcloud container clusters describe ${google_container_cluster.main.name} --format="value(status)"`
        [[ "$${status}" != "RUNNING" && $${try} -lt $${max_retries} ]] || break
        echo "cluster ${google_container_cluster.main.name} not ready. retrying $${try}/$${max_retries}"
        try=$$((try+1))
        sleep 3
      done

      gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone}
      kubectl cluster-info
      kubectl create clusterrolebinding ${var.service_account} --clusterrole=cluster-admin --user=${var.gcp_user}
    EOT
  }
}
