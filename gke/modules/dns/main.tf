resource "null_resource" "install_external_dns" {
  provisioner "local-exec" {
    command = <<EOT
      set -e

      max_retries=20
      try=0
      while : ; do
        status=`gcloud container clusters describe ${var.cluster_name} --format="value(status)"`
        [[ "$${status}" != "RUNNING" && $${try} -lt $${max_retries} ]] || break
        echo "cluster ${var.cluster_name} not ready. retrying $${try}/$${max_retries}"
        try=$$((try+1))
        sleep 3
      done

      gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone}
      echo '${data.template_file.external_dns.rendered}' | kubectl apply -f -
    EOT
  }
}

data "template_file" "external_dns" {
  template = "${file("${path.module}/tmpl/deployment.yaml")}"

  vars {
    version = "${var.external_dns_version}"
    cluster_identifier = "${var.cluster_identifier}"
  }
}
