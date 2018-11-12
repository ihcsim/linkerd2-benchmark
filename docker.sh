#!/bin/bash

# This script performs load tests against 2 Fortio echo servers, running as as Docker containers.
# The load generator uses the `fortio load` command to send HTTP and GRPC loads to the echo servers.
# Use the -h or --help option to see usage information.
# All the JSON result data is stored in the $REPORTS_FOLDER folder.

PROJECT=linkerd2-benchmark
FORTIO_VERSION=1.3.0

TARGET_COUNT=2
TARGET_HOST=fortio-echo
HTTP_PORT=8080
GRPC_PORT=8079
NETWORK=${PROJECT}

REPORTS_FOLDER=`pwd`/reports

# Refer https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass for tips on setting up the load tests.
QUERIES_PER_SECOND_HTTP=${QUERIES_PER_SECOND_HTTP:-1000}
QUERIES_PER_SECOND_GRPC=${QUERIES_PER_SECOND_GRPC:-1000}
CONNECTIONS_COUNT=${CONNECTIONS_COUNT:-16}
TEST_RUN_DURATION=${TEST_RUN_DURATION:-5s}

# Refer https://github.com/fortio/fortio/wiki/FAQ#my-histogram-graphs-are-blocky--not-many-data-points-
HISTOGRAM_RESOLUTION=${HISTOGRAM_RESOLUTION:-0.0001}

function usage() {
  echo -e "Support environment variables:\n  INIT - Re-create all Docker containers, volumes, network and folders\n  QUERIES_PER_SECOND_HTTP - Queries per second for the HTTP load\n  QUERIES_PER_SECOND_GRPC - Queries per second for the GRPC load\n  CONNECTIONS_COUNT - Number of connections/goroutine/threads used by the load generator container\n  TEST_RUN_DURATION - Duration of each test run (in golang duration format)\n  HISTOGRAM_RESOLUTION - Resolution of the histogram lowest buckets in seconds (in golang float format)"
}

function cleanup() {
  echo "Deleting previous containers"
  rm -rf ${REPORTS_FOLDER}
  docker rm -f -v `docker ps -a -q -f "label=project=linkerd2-benchmark"`
  docker network rm ${NETWORK}
}

function setup() {
  echo "Creating Docker network ${NETWORK}"
  docker network create ${NETWORK}

  for INDEX in $(seq 0 $((TARGET_COUNT-1))); do
    CONTAINER=${TARGET_HOST}-${INDEX}
    echo "Creating Docker container ${CONTAINER}"

    mkdir -p ${REPORTS_FOLDER}/docker.sh/${CONTAINER}
    docker run -d --name ${CONTAINER} \
      --network ${NETWORK} \
      -p ${HTTP_PORT} \
      -p ${GRPC_PORT} \
      --mount=type=bind,source=${REPORTS_FOLDER}/docker.sh/${CONTAINER},target=/data \
      --label project=linkerd2-benchmark \
      fortio/fortio:${FORTIO_VERSION} \
      server \
        -data-dir=/data \
        -profile "/data/profile"
  done

  mkdir -p ${REPORTS_FOLDER}/docker.sh/
  docker run -d --name load-generator \
    --network ${NETWORK} \
    --mount=type=bind,source=${REPORTS_FOLDER}/docker.sh,target=/data \
    --label project=linkerd2-benchmark \
    fortio/fortio:${FORTIO_VERSION}
}

function sleep5s() {
  echo "Waiting for containers to be ready"
  sleep 5s
}

function run_tests() {
  for INDEX in $(seq 0 $((TARGET_COUNT-1))); do
    CONTAINER=${TARGET_HOST}-${INDEX}

    echo -e "Load test:\n  Container: ${CONTAINER}\n  Protocol: HTTP\n  QPS: ${QUERIES_PER_SECOND_HTTP} query/second"
    docker exec load-generator \
      fortio load \
        -a -data-dir=/data \
        -qps ${QUERIES_PER_SECOND_HTTP} \
        -c ${CONNECTIONS_COUNT} \
        -r ${HISTOGRAM_RESOLUTION} \
        -t ${TEST_RUN_DURATION} \
        -labels "${CONTAINER} http ${QUERIES_PER_SECOND_HTTP} ${TEST_RUN_DURATION}" \
        -profile "/data/profile" \
        ${CONTAINER}:${HTTP_PORT}/echo

    echo -e "Load test:\n  Container: ${CONTAINER}\n  Protocol: GRPC\n  QPS: ${QUERIES_PER_SECOND_GRPC} query/second"
    docker exec load-generator \
      fortio load \
        -a -data-dir=/data \
        -grpc -ping \
        -qps ${QUERIES_PER_SECOND_GRPC} \
        -c ${CONNECTIONS_COUNT} \
        -r ${HISTOGRAM_RESOLUTION} \
        -t ${TEST_RUN_DURATION} \
        -labels "${CONTAINER} grpc ${QUERIES_PER_SECOND_GRPC} ${TEST_RUN_DURATION}" \
        -profile "/data/profile" \
        ${CONTAINER}:${GRPC_PORT}
  done
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

if [ ! -z ${INIT} ]; then
  cleanup
  setup
  sleep5s
fi

run_tests
