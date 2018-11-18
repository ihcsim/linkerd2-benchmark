#!/bin/bash

set -xe

NAMESPACE=benchmark-load

for DURATION in 120 500 1000 1500 2000; do
  CMD=RUN_TESTS QUERIES_PER_SECOND_HTTP=${DURATION} QUERIES_PER_SECOND_GRPC=${DURATION} ./gke.sh
  sleep 30s
  POD=`kubectl -n ${NAMESPACE} get po -l job=load-generator -o jsonpath='{.items[*].metadata.name}'`
  kubectl -n ${NAMESPACE} logs -f ${POD} > report-${DURATION}qps.log
  kubectl -n ${NAMESPACE} delete job load-generator
  sleep 600s
done
