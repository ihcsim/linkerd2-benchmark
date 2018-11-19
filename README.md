# Linkerd2 Benchmark
This project contains scripts to load-test the [Linkerd2](https://linkerd.io/) and [Istio](https://istio.io) proxy using [Fortio](https://fortio.org/).

Fortio is used as both the load generator and the echo server because of its lightweight footprint, its support for HTTP, HTTP2, GRPC and TLS, with minimal dependencies and configurations. For more information on Fortio (including its difference with [wrk](https://github.com/wg/wrk)), refer to this [FAQ](https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass).

* [GKE](#gke)
* [Minikube](#minikube)
* [Docker](#docker)

All the reports can be found in the [reports folder](reports).

## GKE
To run the gke.sh script, you will need:

* [kubectl v1.10.7](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [Terraform v0.11.7](https://www.terraform.io/downloads.html)
* [gcloud (Google Cloud SDK 225.0.0)](https://cloud.google.com/sdk/install)
* [Linkerd2 CLI](https://linkerd.io/2/getting-started/#step-1-install-the-cli)
* A GCP project to host the GKE cluster
* A GCP service account with at least these roles:
  * Kubernetes Engine Cluster Admin
  * Compute Network Admin
  * Storage Object Admin
  * Compute Instance Admin (v1)

Follow the instructions in the Istio [documentation](https://istio.io/docs/setup/kubernetes/quick-start-gke-dm/) to assign additional roles to your default GCP compute service account.

The script starts up a load generator [job](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) to perform a series of HTTP and GRPC load tests on 6 Fortio echo servers, where 2 of them serve as the baseline, 2 are Linkerd2-meshed and 2 are Istio-meshed.

Usage:
```
# see all supported options and environment variables
$ ./gke.sh -h

# use Terraform to provision a GKE cluster
# must update the Terraform Cloud Storage backend variables in gke/main.tf to match your environment
$ CMD=INIT_CLUSTER GOOGLE_CREDENTIALS=<path_to_service_account_json_key_file> GCP_PROJECT=<gcp_project_id> GCP_USER=<gcloud_username> GKE_SERVICE_ACCOUNT=<service_account__for_gke> ./gke.sh

# build and push the load generator Docker image to GCR
# then set up the Linkerd2 and Istio control planes
$ CMD=INIT_CONTROL_PLANES DOCKER_IMAGE_REPO=<your_image_repo> ./gke.sh

# deploy the baseline, Linkerd2-meshed and Istio-meshed echo servers
$ CMD=INIT_ECHO_SERVERS ./gke.sh

# run the tests
$ CMD=RUN_TESTS ./gke.sh

# use Terraform to destroy the GKE cluster
$ CMD=CLEANUP GOOGLE_CREDENTIALS=<path_to_service_account_json_key_file> GCP_PROJECT=<gcp_project_id> GCP_USER=<gcloud_username> GKE_SERVICE_ACCOUNT=<service_account__for_gke> ./gke.sh
```

The Terraform scripts create a GKE 1.11.2-gke.18 cluster in the us-west1-a zone. The cluster is comprised of the following node pools:

* `system`: A single node of `n1-standard-2` type to host the `kube-system`, `linkerd` and `istio-system` namespaces.
* `baseline`: A single node of `n1-standard-1` type to host the baseline echo servers. The node is tainted with the `app-family: baseline` taint.
* `linkerd-meshed`: A single node of `n1-standard-1` type to host the Linkerd2-meshed echo servers. The node is tainted with the `app-family: linkerd-meshed` taint.
* `istio-meshed`: A single node of `n1-standard-1` type to host the Istio-meshed echo servers. The node is tainted with the `app-family: istio-meshed` taint.
* `load-generator`: A single node of `n1-standard-1` type to host the load generator. The node is tainted with the `app-family: load-generator` taint.

Once the GKE cluster is ready, the script creates the following 6 namespaces:

* `linkerd`: This namespace has the Linkerd2 control plane.
* `istio-system`: This namespace has the Istio control plane. It's installed using the helm chart generated per instructions [here](https://istio.io/docs/setup/kubernetes/helm-install/).
* `benchmark-load`: This namespace has the load generator and report server.
* `benchmark-linkerd`: This namespace has 2 Fortio echo server pods that are meshed with the Linkerd2 proxy.
* `benchmark-istio`: This namespace has 2 Fortio echo server pods that are meshed with the Istio proxy.
* `benchmark-baseline`: This namespace has the 2 baseline deployments.

The report server is fronted by an ingress resource. Use the `kubectl -n benchmark-load get ing` command to get its public IPv4. The report will be viewable at `http://<ingress_public_ipv4>`.

The `gke_stress.sh` script can be used to perform stress test on the echo servers where the queries per second rate is gradually increased from 120 gps to 2000 qps. Note that this is a long-running script that goes for at least an hour.

## Minikube
To run the minikube.sh script, you will need:

* [Minikube 0.30.0](https://github.com/kubernetes/minikube/releases/tag/v0.30.0) - enable the ingress and storage class add-ons.
* [Helm v2.11.0](https://github.com/helm/helm/releases/tag/v2.11.0)
* [Linkerd2 CLI](https://linkerd.io/2/getting-started/#step-1-install-the-cli)

Per Istio [documentation](https://istio.io/docs/setup/kubernetes/platform-setup/minikube/), ensure that your Minikube k8s cluster is started with at least 8192 MB of memory and 4 CPUs.

The script starts up a load generator [job](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) to perform a series of HTTP and GRPC load tests on 2 Fortio echo servers.

It creates the following namespaces:

* `linkerd`: This namespace has the Linkerd2 control plane.
* `benchmark-load`: This namespace has the load generator and report server.
* `benchmark-baseline`: This namespace serves as the baseline with 2 deployments of the Fortio echo servers.
* `benchmark-linkerd`: The Fortio echo server pods in this namespace are meshed with the Linkerd2 proxy.
* `benchmark-istio`: The Fortio echo server pods in this namespace are meshed with the Istio proxy. Istio is installed using the helm chart generated per instructionc [here](https://istio.io/docs/setup/kubernetes/helm-install/).

By default, the load generator hits each echo server pod with 100 HTTP requests/second and 100 GRPC requests/second, for a duration of 10 seconds each. It repeats this load 10 times on the baseline and meshed echo servers. The JSON report files are persisted in the Minikube `/tmp` folder via persistent volume claim resources, and are accessible via the ingress set-up.

Usage:
```
# see usage
# ./minikube.sh -h

# build and push the load generator Docker image to Minikube
# then install the Linkerd2 and Istio control planes
# finally, deploy the baseline, Linkerd2-meshed and Istio-meshed echo servers
$ CMD=INIT ./minikube.sh

# set up the job resource to run the load test
# also, deploy the report server
$ CMD=RUN_TESTS ./minikube.sh

# delete the linkerd, istio-system, benchmark-baseline, benchmark-linkerd, benchmark-istio namespaces
$ CMD=CLEANUP ./minikube.sh
```

To view the reports, visit `http://<your_minikube_ip>`.

## Docker
To run the `docker.sh` script, you will need:

* [Docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
* [Fortio v1.3.0](https://github.com/fortio/fortio)

The `docker.sh` script creates a local Docker network linking 2 echo servers and 1 load generator. The load generator sends HTTP and GRPC load to both echo servers. This script doesn't install Linkerd2. The reports are stored in the `reports` folder.

Usage:
```
# see usage
$ docker.sh -h

# set up all the Docker containers
$ INIT=true ./docker.sh
```
The above command will set up the Docker containers and run the load tests. All the report JSON files will be saved in the git-ignored reports/ folder by default.

To view the reports:
```
$ fortio report -data-dir reports/docker.sh/samples
```
