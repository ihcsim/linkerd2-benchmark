resource "google_container_cluster" "main" {
  name = "main"
  project = "${var.project}"
  zone = "${var.zone}"

  min_master_version = "${var.gke_version}"
  node_version = "${var.gke_version}"

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
    name = "${var.kube_system_pool["name"]}"
    initial_node_count = "${var.kube_system_pool["initial_node_count"]}"

    node_config {
      machine_type = "${var.kube_system_pool["machine_type"]}"
      disk_size_gb = "${var.kube_system_pool["disk_size_gb"]}"
      disk_type = "${var.disk_type}"
      image_type = "${var.image_type}"
      oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
      service_account = "${var.service_account}"

      labels = {
        node_group = "${var.kube_system_pool["name"]}"
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

resource "google_container_node_pool" "linkerd-system" {
  provider = "google-beta"

  name = "linkerd-system"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.system_pool["initial_node_count"]}"

  node_config {
    machine_type = "${var.system_pool["machine_type"]}"
    disk_size_gb = "${var.system_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "linkerd-system"
    }

    taint = {
      key = "app-family"
      value = "linkerd-system"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "istio-system" {
  provider = "google-beta"

  name = "istio-system"

  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.system_pool["initial_node_count"]}"

  node_config {
    machine_type = "${var.system_pool["machine_type"]}"
    disk_size_gb = "${var.system_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "istio-system"
    }

    taint = {
      key = "app-family"
      value = "istio-system"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "baseline" {
  provider = "google-beta"

  name = "baseline"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_count"]}"

  node_config {
    preemptible = true
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.worker_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "baseline"
    }

    taint = {
      key = "app-family"
      value = "baseline"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "linkerd_meshed" {
  provider = "google-beta"

  name = "linkerd-meshed"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_count"]}"

  node_config {
    preemptible = true
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.worker_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "linkerd-meshed"
    }

    taint = {
      key = "app-family"
      value = "linkerd-meshed"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "istio_meshed" {
  provider = "google-beta"

  name = "istio-meshed"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_count"]}"

  node_config {
    preemptible = true
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.worker_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "istio-meshed"
    }

    taint = {
      key = "app-family"
      value = "istio-meshed"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair = "${var.node_auto_repair}"
    auto_upgrade = "${var.node_auto_upgrade}"
  }
}

resource "google_container_node_pool" "load_generator" {
  provider = "google-beta"

  name = "load-generator"
  cluster = "${google_container_cluster.main.name}"
  zone = "${var.zone}"

  initial_node_count = "${var.worker_pool["initial_node_count"]}"

  node_config {
    machine_type = "${var.worker_pool["machine_type"]}"
    disk_size_gb = "${var.worker_pool["disk_size_gb"]}"
    disk_type = "${var.disk_type}"
    image_type = "${var.image_type}"
    oauth_scopes = ["compute-rw", "storage-ro", "logging-write", "monitoring"]
    service_account = "${var.service_account}"

    labels = {
      node_group = "load-generator"
    }

    taint = {
      key = "app-family"
      value = "load-generator"
      effect = "NO_SCHEDULE"
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
      #!/bin/sh
      set -e

      gcloud config set project ${var.project}
      max_retries=20
      try=0
      while : ; do
        status=`gcloud container clusters describe --zone ${var.zone} ${google_container_cluster.main.name} --format="value(status)"`
        if [ "$${status}" = "RUNNING" -o $${try} -gt $${max_retries} ]; then
          break
        fi

        echo "cluster ${google_container_cluster.main.name} not ready. retrying $${try}/$${max_retries}"
        try=$$((try+1))
        sleep 3
      done

      gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone}
      kubectl cluster-info
      kubectl create clusterrolebinding ${var.gcp_user} --clusterrole=cluster-admin --user=${var.gcp_user}
    EOT
  }
}
