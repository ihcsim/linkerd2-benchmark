#!/bin/bash

# This script performs HTTP and GRPC load tests against 2 Fortio echo servers, deployed as 'deployment' resources on Minikube.
# The load generator runs as 'job' resources.
# Use the -h or --help option to see usage information.
# The YAML manifest of these resources can be found in the 'yaml' folder.

TARGETS_COUNT=${TARGETS_COUNT:-2}
PERSISTENT_DISK_SIZE=${PERSISTENT_DISK_SIZE:-5}Gi

# Refer https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass for tips on setting up the load tests.
QUERIES_PER_SECOND_HTTP=${QUERIES_PER_SECOND_HTTP:-100}
QUERIES_PER_SECOND_GRPC=${QUERIES_PER_SECOND_GRPC:-100}
CONNECTIONS_COUNT=${CONNECTIONS_COUNT:-4}
TEST_RUN_DURATION=${TEST_RUN_DURATION:-10s}
TEST_RUN_TOTAL=${TEST_RUN_TOTAL:-10}

# refer https://github.com/fortio/fortio/wiki/FAQ#my-histogram-graphs-are-blocky--not-many-data-points-
HISTOGRAM_RESOLUTION=${HISTOGRAM_RESOLUTION:-0.0001}

NAMESPACE_BENCHMARK_BASELINE=benchmark-baseline
NAMESPACE_BENCHMARK_LINKERD=benchmark-linkerd
NAMESPACE_BENCHMARK_ISTIO=benchmark-istio
NAMESPACE_BENCHMARK_LOAD=benchmark-load
NAMESPACE_LINKERD=linkerd
NAMESPACE_ISTIO=istio-system
DOCKER_IMAGE_REPO=minikube

function usage() {
  echo -e "Support environment variables:\n  INIT - Set up Linkerd2 and istio control planes, and the Fortio servers and load generator\n  CLEANUP - Delete all namespaces, deployments, jobs and persistent volumes\n  TARGETS_COUNT - Number of echo servers under test\n  PERSISTENT_DISK_SIZE - Persistent disk size in GiB.  QUERIES_PER_SECOND_HTTP - Queries per second for the HTTP load\n  QUERIES_PER_SECOND_GRPC - Queries per second for the GRPC load\n  CONNECTIONS_COUNT - Number of connections/goroutine/threads used by each load generator container\n  TEST_RUN_DURATION - Duration of each test run (in golang duration format)\n  TEST_RUN_TOTAL - Number of times to repeat the test run. Each test run lasts for the duration defined by TEST_RUN_DURATION\n  HISTOGRAM_RESOLUTION - Resolution of the histogram lowest buckets in seconds (in golang float format)"
}

function cleanup() {
  echo "Deleting previous namespaces"
  kubectl delete ns ${NAMESPACE_BENCHMARK_BASELINE} ${NAMESPACE_BENCHMARK_LINKERD} ${NAMESPACE_BENCHMARK_LOAD} ${NAMESPACE_BENCHMARK_ISTIO} ${NAMESPACE_LINKERD} ${NAMESPACE_ISTIO}
}

function build_dockerfile() {
  eval `minikube docker-env`
  docker build --rm -t ${DOCKER_IMAGE_REPO}/load-generator yaml/load-generator
}

function install_linkerd() {
  echo "Installing Linkerd"
  linkerd install | kubectl apply -f -
}

function install_istio() {
  echo "Installing istio"
  kubectl create ns ${NAMESPACE_ISTIO}
  kubectl -n ${NAMESPACE_ISTIO} apply -f yaml/istio-1.0.3.yaml
}

function create_baseline() {
  echo "Creating baseline namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_BASELINE}
  kubectl -n ${NAMESPACE_BENCHMARK_BASELINE} apply -f yaml/echo-server.yaml
}

function create_linkerd_meshed() {
  echo "Creating Linkerd2-meshed namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_LINKERD}
  linkerd inject yaml/echo-server.yaml | kubectl -n ${NAMESPACE_BENCHMARK_LINKERD} apply -f -
}

function create_istio_meshed() {
  echo "Creating istio-meshed namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_ISTIO}
  kubectl label ns ${NAMESPACE_BENCHMARK_ISTIO} istio-injection=enabled
  kubectl -n ${NAMESPACE_BENCHMARK_ISTIO} apply -f yaml/echo-server.yaml
}

function run_tests() {
  echo "Running load tests"
  kubectl create ns ${NAMESPACE_BENCHMARK_LOAD}

  sed "s/{{ TARGETS_COUNT }}/${TARGETS_COUNT}/g; s/{{ QUERIES_PER_SECOND_HTTP }}/${QUERIES_PER_SECOND_HTTP}/g; s/{{ QUERIES_PER_SECOND_GRPC }}/${QUERIES_PER_SECOND_GRPC}/g; s/{{ CONNECTIONS_COUNT }}/${CONNECTIONS_COUNT}/g; s/{{ TEST_RUN_DURATION }}/${TEST_RUN_DURATION}/g; s/{{ TEST_RUN_TOTAL }}/${TEST_RUN_TOTAL}/g; s/{{ HISTOGRAM_RESOLUTION }}/${HISTOGRAM_RESOLUTION}/g; s/{{ PERSISTENT_DISK_SIZE }}/${PERSISTENT_DISK_SIZE}/g; s/{{ DOCKER_IMAGE_REPO }}/${DOCKER_IMAGE_REPO}/g; s/{{ NAMESPACE_BENCHMARK_BASELINE }}/${NAMESPACE_BENCHMARK_BASELINE}/g; s/{{ NAMESPACE_BENCHMARK_LINKERD }}/${NAMESPACE_BENCHMARK_LINKERD}/g; s/{{ NAMESPACE_BENCHMARK_ISTIO }}/${NAMESPACE_BENCHMARK_ISTIO}/g" yaml/load-generator/resources.yaml | kubectl -n ${NAMESPACE_BENCHMARK_LOAD} apply -f -
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

if [ ! -z "${CLEANUP}" ]; then
  cleanup
  exit $?
fi

if [ ! -z "${INIT}" ]; then
  set -e

  build_dockerfile
  install_linkerd
  install_istio

  echo "Waiting for control planes to be ready. This will take a few minutes."
  sleep 7m

  create_baseline
  create_linkerd_meshed
  create_istio_meshed
  exit 0
fi

run_tests
