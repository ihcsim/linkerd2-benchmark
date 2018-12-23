#!/bin/bash

# This script is used in the Job resource to perform HTTP and GRPC load tests on the Fortio echo servers.
# The $TARGETS_COUNT variable determines the number of echo servers under test. It's also used in a 'for' loop to provide the ordinal suffix of each echo server's name.
# All JSON reports are written to the /data folder by default.
# Use the -h or --help option to see usage information.

TARGET_HOST=${TARGET_HOST:-fortio-echo}
HTTP_PORT=${HTTP_PORT:-8080}
GRPC_PORT=${GRPC_PORT:-8079}

DATA_DIR=${DATA_DIR:-/data}

# Refer https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass for tips on setting up the load tests.
QUERIES_PER_SECOND_HTTP=${QUERIES_PER_SECOND_HTTP:-100}
QUERIES_PER_SECOND_GRPC=${QUERIES_PER_SECOND_GRPC:-100}
CONNECTIONS_COUNT=${CONNECTIONS_COUNT:-4}
TEST_RUN_DURATION=${TEST_RUN_DURATION:-10s}
TEST_RUN_TOTAL=${TEST_RUN_TOTAL:-10}

# Refer https://github.com/fortio/fortio/wiki/FAQ#my-histogram-graphs-are-blocky--not-many-data-points-
HISTOGRAM_RESOLUTION=${HISTOGRAM_RESOLUTION:-0.0001}

NAMESPACE_BENCHMARK_BASELINE=${NAMESPACE_BENCHMARK_BASELINE:-benchmark-baseline}
NAMESPACE_BENCHMARK_LINKERD=${NAMESPACE_BENCHMARK_LINKERD:=-benchmark-linkerd}

function usage() {
  echo -e "Support environment variables:\n  INIT - Install the latest version of Fortio\n  HTTP_PORT - HTTP port of the echo server to send the load to\n  GRPC_PORT - GRPC port of the echo server to send the load to\n  DATA_DIR - Data directory to write the result JSON files to\n  QUERIES_PER_SECOND_HTTP - Queries per second for the HTTP load\n  QUERIES_PER_SECOND_GRPC - Queries per second for the GRPC load\n  CONNECTIONS_COUNT - Number of connections/goroutine/threads used by the load generator container\n  TEST_RUN_DURATION - Duration of each test run (in golang duration format)\n  TEST_RUN_TOTAL - Number of times to repeat the test run. Each test run lasts for the duration defined by TEST_RUN_DURATION\n  HISTOGRAM_RESOLUTION - Resolution of the histogram lowest buckets in seconds (in golang float format)"
}

function install_fortio() {
  go get fortio.org/fortio
  fortio -version
}

function run_test_http() {
  fortio load \
    -a -data-dir=${DATA_DIR} \
    -qps ${QUERIES_PER_SECOND_HTTP} \
    -c ${CONNECTIONS_COUNT} \
    -r ${HISTOGRAM_RESOLUTION} \
    -t ${TEST_RUN_DURATION} \
    -labels "http ${MESHED} ${QUERIES_PER_SECOND_HTTP}qps ${TEST_RUN_DURATION} echo-${INDEX} ${TEST_RUN}" \
    -profile "${DATA_DIR}/profile" \
    ${CONTAINER}:${HTTP_PORT}/echo
}

function run_test_grpc() {
  fortio load \
    -a -data-dir=${DATA_DIR} \
    -grpc -ping \
    -qps ${QUERIES_PER_SECOND_GRPC} \
    -c ${CONNECTIONS_COUNT} \
    -r ${HISTOGRAM_RESOLUTION} \
    -t ${TEST_RUN_DURATION} \
    -labels "grpc ${MESHED} ${QUERIES_PER_SECOND_GRPC}qps ${TEST_RUN_DURATION} echo-${INDEX} ${TEST_RUN}" \
    -profile "${DATA_DIR}/profile" \
    ${CONTAINER}:${GRPC_PORT}
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

if [ ! -z ${INIT} ]; then
  install_fortio
fi

for TEST_RUN in $(seq 0 $((TEST_RUN_TOTAL-1))); do
  CONTAINER=${TARGET_HOST}-0.${NAMESPACE_BENCHMARK_BASELINE} MESHED=baseline TEST_RUN=${TEST_RUN} run_test_http
  CONTAINER=${TARGET_HOST}-0.${NAMESPACE_BENCHMARK_ISTIO} MESHED=istio TEST_RUN=${TEST_RUN} run_test_http
done
