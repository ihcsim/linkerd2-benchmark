#!/bin/bash

set -e

source common.sh

PROJECT_FOLDER=gke
CLUSTER_NAME=${CLUSTER_NAME:-main}
CLUSTER_ZONE=${CLUSTER_ZONE:-us-west1-a}
GCP_PROJECT=${GCP_PROJECT:-linkerd2-benchmark}

DOCKER_IMAGE_REPO=${DOCKER_IMAGE_REPO:-us.gcr.io/linkerd2-benchmark}

LOAD_GENERATOR_DOCKERFILE=${PROJECT_FOLDER}/yaml/load-generator

RESOURCE_FILE_ISTIO=${PROJECT_FOLDER}/yaml/istio-1.0.3.yaml
RESOURCE_FILE_ISTIO_STRESS_TEST=${PROJECT_FOLDER}/yaml/istio-1.0.3-stress-test-mode.yaml
RESOURCE_FILE_LINKERD=${PROJECT_FOLDER}/yaml/linkerd-2.1.0.yaml
RESOURCE_FILE_ECHO_SERVER_BASELINE=${PROJECT_FOLDER}/yaml/echo-server/baseline-toleration.yaml
RESOURCE_FILE_ECHO_SERVER_LINKERD=${PROJECT_FOLDER}/yaml/echo-server/linkerd-toleration.yaml
RESOURCE_FILE_ECHO_SERVER_ISTIO=${PROJECT_FOLDER}/yaml/echo-server/istio-toleration.yaml
RESOURCE_FILE_LOAD_GENERATOR=${PROJECT_FOLDER}/yaml/load-generator/resources.yaml

function usage() {
  echo "This script creates the GKE environment used to perform load tests on the Linkerd2 and Istio, using Fortio as the load generator and echo servers.

Usage:
  # set up the GKE cluster
  # must update the Terraform Cloud Storage backend variables in gke/main.tf to match your environment
  CMD=INIT_CLUSTER GOOGLE_CREDENTIALS=<path_to_service_account_json_key_file> GCP_PROJECT=<gcp_project_id> GCP_USER=<username_to_run_gcloud> GKE_SERVICE_ACCOUNT=<gke_service_account_name> ./gke.sh

  # build the load generator docker images
  CMD=BUILD_LOAD_GENERATOR_DOCKER ./gke.sh

  # set up the Linkerd2 and Istio control planes.
  # specify the ISTIO_STRESS_TEST_MODE=true variable to use the Istio stress-test YAML.
  CMD=INIT_CONTROL_PLANES ./gke.sh

  # set up the baseline, Linkerd2-meshed and Istio-meshed echo servers
  CMD=INIT_ECHO_SERVERS ./gke.sh

  # set up the Job resource to run the load tests
  CMD=RUN_TESTS ./gke.sh

  # clean up
  CMD=CLEANUP GOOGLE_CREDENTIALS=<path_to_service_account_json_key_file> GCP_USER=<username_to_run_gcloud> GKE_SERVICE_ACCOUNT=<gke_service_account_name> ./gke.sh

Supported commands:
  INIT_CLUSTER - Set up the GKE cluster and all the related networking resources using Terraform.
  INIT_CONTROL_PLANES - Set up Linkerd2 and Istio control planes. Provide this flag after the GKE cluster is ready.
  INIT_ECHO_SERVERS - Set up the baseline, linkerd2-meshed and Istio-meshed echo servers.
  RUN_TESTS - Create the Job resource to run the load test.

Supported environment variables:
  CLUSTER_NAME - Name of the GKE cluster
  CLUSTER_ZONE - Zone of the GKE cluster
  GCP_RPOJECT - GCP project ID
  DOCKER_IMAGE_REPO - The name of the Docker image repository. For example, gcr.io/my_gcp_project
"
  common_usage
}

function run_terraform() {
  if [ -z "${GCP_USER}" ]; then
    echo "Can't create GKE cluster. Must provide a value for \$GCP_USER. Use the -h option to see more usage information."
    exit 1
  fi

  if [ -z "${GKE_SERVICE_ACCOUNT}" ]; then
    echo "Can't create GKE cluster. Must provide a value for \$GKE_SERVICE_ACCOUNT. Use the -h option to see more usage information."
    exit 1
  fi

  terraform init \
    -var gcp_user=${GCP_USER} \
    -var gke_service_account="${GKE_SERVICE_ACCOUNT}" \
    -var project="${GCP_PROJECT}" \
    ${PROJECT_FOLDER}

  terraform validate \
    -var gcp_user=${GCP_USER} \
    -var gke_service_account="${GKE_SERVICE_ACCOUNT}" \
    -var project="${GCP_PROJECT}" \
    ${PROJECT_FOLDER}

  terraform apply \
    -var gcp_user=${GCP_USER} \
    -var gke_service_account="${GKE_SERVICE_ACCOUNT}" \
    -var project="${GCP_PROJECT}" \
    ${PROJECT_FOLDER}
}

function cleanup() {
  echo "$GCP_PROJECT"
  terraform destroy \
    -var gcp_user=${GCP_USER} \
    -var gke_service_account="${GKE_SERVICE_ACCOUNT}" \
    -var project="${GCP_PROJECT}" \
    ${PROJECT_FOLDER}
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

echo "Running command ${CMD}"
case "${CMD}" in
  INIT_CLUSTER)
    run_terraform
    ;;

  BUILD_LOAD_GENERATOR_DOCKER)
    build_dockerfile
    push_docker_image
    ;;

  INIT_CONTROL_PLANES)

    cluster_readiness
    install_linkerd

    if [ ! -z "${ISTIO_STRESS_TEST_MODE}" ]; then
      install_istio_stress_test_mode
    else
      install_istio
    fi
    ;;

  INIT_ECHO_SERVERS)
    set +e
    create_baseline
    create_linkerd_meshed
    create_istio_meshed
    ;;

  RUN_TESTS)
    set +e
    run_tests
    ;;

  CLEANUP)
    cleanup
    ;;

  *)
    usage
    ;;
esac
