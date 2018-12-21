#!/bin/bash

set -e

DOCKER_IMAGE_REPO=minikube
LOAD_GENERATOR_DOCKERFILE=minikube/yaml/load-generator

RESOURCE_FILE_ISTIO=minikube/yaml/istio-1.0.3.yaml
RESOURCE_FILE_LINKERD=minikube/yaml/linkerd-2.1.0.yaml
RESOURCE_FILE_ECHO_SERVER_BASELINE=minikube/yaml/echo-server.yaml
RESOURCE_FILE_ECHO_SERVER_LINKERD=minikube/yaml/echo-server.yaml
RESOURCE_FILE_ECHO_SERVER_ISTIO=minikube/yaml/echo-server.yaml
RESOURCE_FILE_LOAD_GENERATOR=minikube/yaml/load-generator/resources.yaml

source common.sh

function usage() {
  echo "This script creates the Minikube instance used to perform load tests on the Linkerd2 and Istio, using Fortio as the load generator and echo servers.

Per Istio's installation instructions for Minikube, ensure your instance has at least 4 CPUs and 8096 MB of RAM.

Usage:
  # build and push the load generator Docker image to Minikube
  # then install the Linkerd2 and Istio control planes
  # finally, deploy the baseline, Linkerd2-meshed and Istio-meshed echo servers
  $ CMD=INIT ./minikube.sh

  # set up the job resource to run the load test
  # also, deploy the report server
  $ CMD=RUN_TESTS ./minikube.sh

  # delete the linkerd, istio-system, benchmark-baseline, benchmark-linkerd, benchmark-istio namespaces
  $ CMD=CLEANUP ./minikube.sh
"
  common_usage
}

function cleanup() {
  echo "Deleting all namespaces"
  kubectl delete ns ${NAMESPACE_BENCHMARK_BASELINE} ${NAMESPACE_BENCHMARK_LINKERD} ${NAMESPACE_BENCHMARK_LOAD} ${NAMESPACE_BENCHMARK_ISTIO} ${NAMESPACE_LINKERD} ${NAMESPACE_ISTIO}
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

case "${CMD}" in
  INIT)
    eval `minikube docker-env`
    build_dockerfile
    install_linkerd
    install_istio

    echo "Waiting for control planes to be ready. This will take a few minutes."
    sleep 600s

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

esac
