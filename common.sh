#!/bin/bash

TARGETS_COUNT=${TARGETS_COUNT:-2}
PERSISTENT_DISK_SIZE=${PERSISTENT_DISK_SIZE:-5}Gi

# Refer https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass for tips on setting up the load tests.
QUERIES_PER_SECOND_HTTP=${QUERIES_PER_SECOND_HTTP:-0}
QUERIES_PER_SECOND_GRPC=${QUERIES_PER_SECOND_GRPC:-0}
CONNECTIONS_COUNT=${CONNECTIONS_COUNT:-32}
TEST_RUN_DURATION=${TEST_RUN_DURATION:-30s}
TEST_RUN_TOTAL=${TEST_RUN_TOTAL:-10}

# refer https://github.com/fortio/fortio/wiki/FAQ#my-histogram-graphs-are-blocky--not-many-data-points-
HISTOGRAM_RESOLUTION=${HISTOGRAM_RESOLUTION:-0.0001}

NAMESPACE_BENCHMARK_BASELINE=benchmark-baseline
NAMESPACE_BENCHMARK_LINKERD=benchmark-linkerd
NAMESPACE_BENCHMARK_ISTIO=benchmark-istio
NAMESPACE_BENCHMARK_LOAD=benchmark-load
NAMESPACE_LINKERD=linkerd
NAMESPACE_ISTIO=istio-system

function build_dockerfile() {
  docker build --rm -t ${DOCKER_IMAGE_REPO}/load-generator ${LOAD_GENERATOR_DOCKERFILE}
}

function push_docker_image() {
  docker push ${DOCKER_IMAGE_REPO}/load-generator
}

function cluster_readiness() {
  max_retries=20
  try=0
  while : ; do
    status=`gcloud container clusters describe --zone ${CLUSTER_ZONE} ${CLUSTER_NAME} --format="value(status)"`
    [[ "${status}" != "RUNNING" && ${try} -lt ${max_retries} ]] || break

    echo "cluster ${CLUSTER_NAME} not ready. retrying ${try}/${max_retries}"
    try=$((try+1))
    sleep 3
  done
}

function install_linkerd() {
  echo "Installing Linkerd"
  linkerd install | kubectl apply -f -
}

function install_istio() {
  echo "Installing istio"
  kubectl create ns ${NAMESPACE_ISTIO}
  kubectl -n ${NAMESPACE_ISTIO} apply -f ${RESOURCE_FILE_ISTIO}
}

function create_baseline() {
  echo "Creating baseline namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_BASELINE}
  kubectl -n ${NAMESPACE_BENCHMARK_BASELINE} apply -f ${RESOURCE_FILE_ECHO_SERVER_BASELINE}
}

function create_linkerd_meshed() {
  echo "Creating Linkerd2-meshed namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_LINKERD}
  linkerd inject ${RESOURCE_FILE_ECHO_SERVER_LINKERD} | kubectl -n ${NAMESPACE_BENCHMARK_LINKERD} apply -f -
}

function create_istio_meshed() {
  echo "Creating istio-meshed namespace"
  kubectl create ns ${NAMESPACE_BENCHMARK_ISTIO}
  kubectl label ns ${NAMESPACE_BENCHMARK_ISTIO} istio-injection=enabled
  kubectl -n ${NAMESPACE_BENCHMARK_ISTIO} apply -f ${RESOURCE_FILE_ECHO_SERVER_ISTIO}
}

function run_tests() {
  echo "Running load tests"
  kubectl create ns ${NAMESPACE_BENCHMARK_LOAD}

  sed "s/{{ TARGETS_COUNT }}/${TARGETS_COUNT}/g; s/{{ QUERIES_PER_SECOND_HTTP }}/${QUERIES_PER_SECOND_HTTP}/g; s/{{ QUERIES_PER_SECOND_GRPC }}/${QUERIES_PER_SECOND_GRPC}/g; s/{{ CONNECTIONS_COUNT }}/${CONNECTIONS_COUNT}/g; s/{{ TEST_RUN_DURATION }}/${TEST_RUN_DURATION}/g; s/{{ TEST_RUN_TOTAL }}/${TEST_RUN_TOTAL}/g; s/{{ HISTOGRAM_RESOLUTION }}/${HISTOGRAM_RESOLUTION}/g; s/{{ PERSISTENT_DISK_SIZE }}/${PERSISTENT_DISK_SIZE}/g; s|{{ DOCKER_IMAGE_REPO }}|${DOCKER_IMAGE_REPO}|g; s/{{ NAMESPACE_BENCHMARK_BASELINE }}/${NAMESPACE_BENCHMARK_BASELINE}/g; s/{{ NAMESPACE_BENCHMARK_LINKERD }}/${NAMESPACE_BENCHMARK_LINKERD}/g; s/{{ NAMESPACE_BENCHMARK_ISTIO }}/${NAMESPACE_BENCHMARK_ISTIO}/g" ${RESOURCE_FILE_LOAD_GENERATOR} | kubectl -n ${NAMESPACE_BENCHMARK_LOAD} apply -f -
}

function common_usage() {
  echo "Other supported environment variables:
  CLEANUP - Delete all namespaces, deployments, jobs and persistent volumes
  TARGETS_COUNT - Number of echo servers under test
  PERSISTENT_DISK_SIZE - Persistent disk size in GiB.
  QUERIES_PER_SECOND_HTTP - Queries per second for the HTTP load
  QUERIES_PER_SECOND_GRPC - Queries per second for the GRPC load
  CONNECTIONS_COUNT - Number of connections/goroutine/threads used by each load generator container
  TEST_RUN_DURATION - Duration of each test run (in golang duration format)
  TEST_RUN_TOTAL - Number of times to repeat the test run. Each test run lasts for the duration defined by TEST_RUN_DURATION
  HISTOGRAM_RESOLUTION - Resolution of the histogram lowest buckets in seconds (in golang float format)"
}

