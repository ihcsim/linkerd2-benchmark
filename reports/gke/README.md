# Report
This report contains the result of my performance test in a GKE environment. The report charts can be viewed at http://ld2.isim.me

All the report logs are available in the same folder as this README.

* [Environment Set-up](#environment-set-up)
* [How To Read The Charts](#how-to-read-the-charts)
* [Test Scenarios](#test-scenarios)
  * [Test Scenario 1 - Maximum QPS](#test-scenario-1---maximum-qps)
  * [Test Scenario 2 - Resource Utilization](#test-scenario-2---resource-utilization)
  * [Test Scenario 3 - Increasing Load](#test-scenario-3---increasing-load)

## Environment Set-up
The [Terraform scripts](../../gke) used in this experiment provisions a GKE 1.11.2-gke.18 cluster in the us-west1-a zone, follow by the installation of Istio 1.0.3, Linkerd2 edge-18.11.1 and Fortio 1.3.1 on the cluster. This is followed by the instantiation of a series of load tests where the Fortio load generator is used to send HTTP and GRPC requests to the baseline, Linkerd2-meshed and Istio-meshed Fortio echo servers. The response time latency is then captured and graphed by the Fortio report server.

The GKE cluster is comprised of the following node pools:

Node Pool Name   | Machine Type                | k8s Namespace                            | Node Taint                   | # of Echo Servers
---------------- | --------------------------- | ---------------------------------------- | ---------------------------- | -----------------
`system`         | n1-standard-2               | `kube-system`, `linkerd`, `istio-system` | None                         | N/A
`baseline`       | n1-standard-1 (preemptible) | `benchmark-baseline`                     | `app-family: baseline`       | 2
`linkerd-meshed` | n1-standard-1 (preemptible) | `benchmark-linkerd2`                     | `app-family: linkerd-meshed` | 2
`istio-meshed`   | n1-standard-1 (preemptible) | `benchmark-istio`                        | `app-family: istio-meshed`   | 2
`load-generator` | n1-standard-1               | `benchmark-load`                         | `app-family: load-generator` | N/A

The Istio control plane is installed based on the recommended Helm-based production installation instructions found [here](https://istio.io/docs/setup/kubernetes/helm-install/).

## How To Read The Charts
Navigate to http://ld2.isim.me

* To view the histogram of a single test run, select its label from the list.
* To compare the results of multiple test runs, hold down your SHIFT key while selecting their labels.
* The filter text field can be used to facilitate more detailed comparisons between the test runs. For example, to view the results of all the 120qps HTTP tests of the baseline echo servers, enter _http_baseline_120qps_ in the filter and hit ENTER.
* The legend of every chart can be clicked to toggle the inclusion or exclusion of data on the chart.

When 3 or more charts are combined,

* Each dot on the colored lines corresponds to the primary (left) y-axis, representing the min, median, max and different percentiles latencies.
* The top black line corresponds to the secondary (right) y-axis, indicating the qps rate.

## Test Scenarios
### Test Scenario 1 - Maximum QPS
There are 2 parts to this test scenario. It begins by attempting to determine how much load (in terms of query-per-second) the echo servers can handle under the current set-up. This is achieved by starting the Fortio load generator with its `-qps` option set to 0, for maximum queries per second rate. The [test script](../../gke.sh) performs 10 performance test runs where each run targets the echo servers with a 30-second HTTP load and a 30-second GRPC load, using 32 concurrent connections.

No limit constraints are set on the proxy's CPU and memory utilization.

(During the test runs, the `istio-telemetry` HPA was effected where it autoscaled the number of `istio-telemetry` pods from 1 to 5. I assume this had no significant impact on the Istio proxies performance.)

The report logs can be found in the `report-0qps-30s-32c-*.log` logs files.

The command used was:
```
$ CMD=RUN_TESTS QUERIES_PER_SECOND_HTTP=0 QUERIES_PER_SECOND_GRPC=0 CONNECTIONS_COUNT=32 TEST_RUN_DURATION=30s  ./gke.sh
```

The following are the URLs to the corresponding charts. Disable the _max_ measurements to exclude the outliers to see the more consistent p99.9 measurements.

Test Case            | URL                                         | Parameters And Response Time(ms)
-------------------- | ------------------------------------------- | --------------------------------
HTTP Baseline        | http://ld2.isim.me/?s=http_baseline_0qps_30 | Duration: 30s<br>qps range: 29.0k - 33.7k<br>Concurrent connections: 32<br>p99.9: 5.60ms - 6.19ms
HTTP Linkerd2-meshed | http://ld2.isim.me/?s=http_linkerd_0qps_30  | Duration: 30s<br>qps range: 10.6k - 11.3k<br>Concurrent connections: 32<br>p99.9: 8.62ms - 11.07ms
HTTP Istio-meshed    | http://ld2.isim.me/?s=http_istio_0qps_30    | Duration: 30s<br>qps range: 3.2k - 3.9k<br>Concurrent connections: 32<br>p99.9: 32.52ms - 72.62ms
GRPC Baseline        | http://ld2.isim.me/?s=grpc_baseline_0qps_30 | Duration: 30s<br>qps range: 14.3k - 20.6k<br>Concurrent connections: 32<br>p99.9: 7.34ms - 11.78ms
GRPC Linker2-meshed  | http://ld2.isim.me/?s=grpc_linkerd_0qps_30  | Duration: 30s<br>qps range: 6.5k - 8.6k<br>Concurrent connections: 32<br>p99.9: 11.48ms - 16.51ms
GRPC Istio-meshed    | http://ld2.isim.me/?s=grpc_istio_0qps_30    | Duration: 30s<br>qps range: 2.8k - 3.7k<br>Concurrent connections: 32<br>p99.9: 30.03ms - 75.20ms

Once the maximum qps rates of all the setups are determined, the next part in this test scenario attempts to load-test the echo servers at 75% of the lowest qps rate. In this case, the Istio-meshed lowest qps rate is used on all echo servers, i.e. 2374 qps for HTTP load and 2113 qps for GRPC. This will also ensure that the load generator doesn't incur _sleep events_ warnings when testing against the Istio-meshed echo servers. For more information on how this helps to improve the accuracy of the load tests, refer to the Fortio [FAQ](https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass).

A total of 10 test runs are performed, where each run is configured to last for 5 minutes. The report logs can be found in the [report-2374qps-5m-32c.log](report-2374qps-5m-32c.log) and [report-http-2374qps-grpc-2113qps-32c.log](report-http-2374qps-grpc-2113qps-32c.log) files.

The command used was:
```
$ CMD=RUN_TESTS QUERIES_PER_SECOND_HTTP=2374 QUERIES_PER_SECOND_GRPC=2113 CONNECTIONS_COUNT=32 TEST_RUN_DURATION=5m  ./gke.sh
```

The following are the URLs to the corresponding charts. Disable the _max_ measurements to remove the outliers. The p99.9 and below measurements are quite consistent.

Test Case            | URL                                            | Parameters And Response Time (ms)
-------------------- | ---------------------------------------------- | ---------------------------------
HTTP Baseline        | http://ld2.isim.me/?s=http_baseline_2374qps_5m | Duration: 5m<br>qps: 2374<br>Concurrent connections: 32<br>p99.9: 5.13ms - 5.85ms
HTTP Linkerd2-meshed | http://ld2.isim.me/?s=http_linkerd_2374qps_5m  | Duration: 5m<br>qps: 2374<br>Concurrent connections: 32<br>p99.9: 7.82ms - 11.47ms
HTTP Istio-meshed    | http://ld2.isim.me/?s=http_istio_2374qps_5m    | Duration: 5m<br>qps: 2374<br>Concurrent connections: 32<br>p99.9: 34.48ms - 53.32ms
GRPC Baseline        | http://ld2.isim.me/?s=grpc_baseline_2113qps_5m | Duration: 5m<br>qps: 2113<br>Concurrent connections: 32<br>p99.9: 9.52ms - 11.21ma
GRPC Linker2-meshed  | http://ld2.isim.me/?s=grpc_linkerd_2113qps_5m  | Duration: 5m<br>qps: 2113<br>Concurrent connections: 32<br>p99.9: 10.74ms - 13.70ms
GRPC Istio-meshed    | http://ld2.isim.me/?s=grpc_istio_2113qps_5m    | Duration: 5m<br>qps: 2113<br>Concurrent connections: 32<br>p99.9: 47.21ms - 63.36ms

### Test Scenario 2 - Resource Utilization
This test scenario attempts to measure the CPU and memory resource utilization of the Linkerd2 and Istio proxies.

[GCP Stackdriver](https://cloud.google.com/stackdriver/) is used to capture the following memory and CPU usage metrics:

Metrics                                                                 | Description                                                                   | Remark
----------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------
Memory Usage<br>`container.googleapis.com/container/memory/bytes_used`  | Memory usage in bytes, broken down by type: evictable and non-evictable.      |
CPU Utilization<br>`container.googleapis.com/container/cpu/utilization` | The percentage of the allocated CPU that is currently in use on the container | This metrics is only available if the CPU limit of the proxy container is set, which can be done by using `kubectl` to `edit` the deployment specs.

Refer to the Stackdriver [docs](https://cloud.google.com/monitoring/api/metrics_gcp#gcp-container) for more information on these metrics.

This test scenario begins by setting the CPU resource limit of the Linkerd2 and Istio proxy containers to 150m. Each test run is configured to send HTTP requests at the maximum qps rate over 32 concurrent connections.

Figure 1 shows the memory usage comparison between the Linkerd2 (blue) and Istio (red) proxies.
The Linkerd2 proxy's memory usage ranges from 4MB to 6MB.
The Istio proxy's memory usage ranges from 36MB to 38MB.

![memory usage 150m cpu 0qps](charts/resource-usage/150mcpu-0qps-memory-usage.png)<br>
_Figure 1 - Linkerd2 proxy and Istio proxy memory usage (150m cpu limit, 0qps, 10sec)_

Figure 2 shows the CPU utilization comparison between the Linkerd2 (orange) and Istio (pink) proxies.
The CPU utilization of both proxies is very similar, hovering between the 15% to 30% range.

![cpu utilization 150m cpu 0qps](charts/resource-usage/150mcpu-0qps-cpu-utilization.png)<br>
_Figure 2 - Linkerd2 proxy and Istio proxy cpu usage time (150m cpu limit, 0qps, 10sec)_

In the second part of this scenario, the CPU resource limit is dropped to 50m. Each test is repeated to send HTTP requests at the maximum qps rate over 32 concurrent connections.

Figure 3 shows the memory usage comparison between the Linkerd2 (blue) and Istio (red) proxies.
The Linkerd2 proxy's memory usage ranges from 4MB to 6MB.
The Istio proxy's memory usage ranges from 25MB to 33MB.

![memory usage 50m cpu 0qps](charts/resource-usage/50mcpu-0qps-memory-usage.png)<br>
_Figure 3 - Linkerd2 proxy and Istio proxy memory usage (50m memory limit, 0qps, 10sec)_

Figure 4 shows the CPU utilization comparison between the Linkerd2 (orange) and Istio (pink) proxies.
The CPU utilization of both proxies is very similar, hovering between the 10% to 28% range.

![cpu utilization 50m cpu 0qps](charts/resource-usage/50mcpu-0qps-cpu-utilization.png)<br>
_Figure 4 - Linkerd2 proxy and Istio proxy cpu usage time (50m cpu limit, 0qps, 10sec)_

In the last part of this test scenario, the CPU resource limit is maintained at 50m. Each test is repeated to send HTTP requests at the 200qps rate over 32 concurrent connections.

Figure 5 shows the memory usage comparison between the Linkerd2 (blue) and Istio (red) proxies.
The Linkerd2 proxy's memory usage ranges from 4MB to 6MB.
The Istio proxy's memory usage ranges from 36MB to 38MB.

![memory usage 50m cpu 200qps](charts/resource-usage/50mcpu-200qps-5min-memory-usage.png)<br>
_Figure 5 - Linkerd2 proxy and Istio proxy memory usage (50m memory limit, 200qps, 5min)_

Figure 6 shows the CPU utilization comparison between the Linkerd2 (orange) and Istio (pink) proxies.
The Linkerd2 proxy's CPU utilization hovers between the 15% to 30% range.
The Istio proxy's CPU utilization hovers between the 40% to 50% range.

![cpu utilization 50m cpu 200qps](charts/resource-usage/50mcpu-200qps-5min-cpu-utilization.png)<br>
_Figure 6 - Linkerd2 proxy and Istio proxy cpu usage time (50m cpu limit, 200qps, 5min)_

### Test Scenario 3 - Increasing Load
In this scenario, the [gke_stress.sh script](../../gke_stress.sh) is used to generate a series of test runs, where subsequent run's qps rate is increased by 500 units. Each run is made up of a 10-second HTTP load and a 10-second GRPC load. The initial qps rate is 120 qps, with 4 concurrent connections. The next run has a qps rate of 500 qps. This increase in the qps rate continues until the final rate of 2000 qps.

The following are the URLs to the corresponding HTTP charts. Disable the _max_ measurements to remove the outliers. The p99.9 and below measurements are quite consistent.

Test Suite                       | URL                                             | Parameters And Respones Time (ms)
-------------------------------- | ----------------------------------------------- | ---------------------------------
HTTP baseline at 120 qps         | http://ld2.isim.me/?s=http_baseline_120qps_10s  | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 1.59ms - 4.68ms
HTTP baseline at 500 qps         | http://ld2.isim.me/?s=http_baseline_500qps_10s  | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 3.33ms - 5.80ms
HTTP baseline at 1000 qps        | http://ld2.isim.me/?s=http_baseline_1000qps_10s | Duration: 10s<br>qps: 1000<br>Concurrent connections: 4<br>p99.9: 3.46ms - 4.60ms
HTTP baseline at 1500 qps        | http://ld2.isim.me/?s=http_baseline_1500qps_10s | Duration: 10s<br>qps: 1500<br>Concurrent connections: 4<br>p99.9: 3.79ms - 4.68ms
HTTP baseline at 2000 qps        | http://ld2.isim.me/?s=http_baseline_2000qps_10s | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 3.84ms - 4.62ms
HTTP Linkerd2-meshed at 120 qps  | http://ld2.isim.me/?s=http_linkerd_120qps_10s   | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 2.48ms - 5.75ms
HTTP Linkerd2-meshed at 500 qps  | http://ld2.isim.me/?s=http_linkerd_500qps_10s   | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 4.44ms - 28.75ms
HTTP Linkerd2-meshed at 1000 qps | http://ld2.isim.me/?s=http_linkerd_1000qps_10s  | Duration: 10s<br>qps: 1000<br>Concurrent connections: 4<br>p99.9: 4.41ms - 5.40ms
HTTP Linkerd2-meshed at 1500 qps | http://ld2.isim.me/?s=http_linkerd_1500qps_10s  | Duration: 10s<br>qps: 1500<br>Concurrent connections: 4<br>p99.9: 4.81ms - 10ms
HTTP Linkerd2-meshed at 2000 qps | http://ld2.isim.me/?s=http_linkerd_2000qps_10s  | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 4.53ms - 5.25ms<br>Number of _sleep falling behind_ events: 1
HTTP Istio-meshed at 120 qps     | http://ld2.isim.me/?s=http_istio_120qps_10s     | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 5.12ms - 21.55ms
HTTP Istio-meshed at 500 qps     | http://ld2.isim.me/?s=http_istio_500qps_10s     | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 7.00ms - 17.00ms
HTTP Istio-meshed at 1000 qps    | http://ld2.isim.me/?s=http_istio_1000qps_10s    | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 13.86ms - 24.17ms
HTTP Istio-meshed at 1500 qps    | http://ld2.isim.me/?s=http_istio_1500qps_10s    | Duration: 10s<br>qps: 1200<br>Concurrent connections: 4<br>p99.9: 13.61ms - 17.63ms<br>Number of _sleep falling behind_ events: 20
HTTP Istio-meshed at 2000 qps    | http://ld2.isim.me/?s=http_istio_2000qps_10s    | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 13.89ms - 16.55ms<br>Number of _sleep falling behind_ events: 20

The following are the URLs to the corresponding GRPC charts. Disable the _max_ measurements to remove the outliers. The p99.9 and below measurements are quite consistent.

Test Suite                       | URL                                             | Parameters And Respones Time (ms)
-------------------------------- | ----------------------------------------------- | ---------------------------------
GRPC baseline at 120 qps         | http://ld2.isim.me/?s=grpc_baseline_120qps_10s  | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 2.90ms - 5.35ms
GRPC baseline at 500 qps         | http://ld2.isim.me/?s=grpc_baseline_500qps_10s  | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 3.50ms - 5.67ms
GRPC baseline at 1000 qps        | http://ld2.isim.me/?s=grpc_baseline_1000qps_10s | Duration: 10s<br>qps: 1000<br>Concurrent connections: 4<br>p99.9: 4.44ms - 5.26ms
GRPC baseline at 1500 qps        | http://ld2.isim.me/?s=grpc_baseline_1500qps_10s | Duration: 10s<br>qps: 1500<br>Concurrent connections: 4<br>p99.9: 4.62ms - 5.42ms
GRPC baseline at 2000 qps        | http://ld2.isim.me/?s=grpc_baseline_2000qps_10s | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 4.66ms - 4.96ms
GRPC Linkerd2-meshed at 120 qps  | http://ld2.isim.me/?s=grpc_linkerd_120qps_10s   | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 4.95ms -  50.54ms
GRPC Linkerd2-meshed at 500 qps  | http://ld2.isim.me/?s=grpc_linkerd_500qps_10s   | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 5.17ms - 8.40ms
GRPC Linkerd2-meshed at 1000 qps | http://ld2.isim.me/?s=grpc_linkerd_1000qps_10s  | Duration: 10s<br>qps: 1000<br>Concurrent connections: 4<br>p99.9: 5.40ms - 10.00ms
GRPC Linkerd2-meshed at 1500 qps | http://ld2.isim.me/?s=grpc_linkerd_1500qps_10s  | Duration: 10s<br>qps: 1500<br>Concurrent connections: 4<br>p99.9: 5.0ms - 5.87ms
GRPC Linkerd2-meshed at 2000 qps | http://ld2.isim.me/?s=grpc_linkerd_2000qps_10s  | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 5.57ms - 6.00ms
GRPC Istio-meshed at 120 qps     | http://ld2.isim.me/?s=grpc_istio_120qps_10s     | Duration: 10s<br>qps: 120<br>Concurrent connections: 4<br>p99.9: 5.51ms - 10.17ms
GRPC Istio-meshed at 500 qps     | http://ld2.isim.me/?s=grpc_istio_500qps_10s     | Duration: 10s<br>qps: 500<br>Concurrent connections: 4<br>p99.9: 6.89ms - 17.20ms
GRPC Istio-meshed at 1000 qps    | http://ld2.isim.me/?s=grpc_istio_1000qps_10s    | Duration: 10s<br>qps: 1000<br>Concurrent connections: 4<br>p99.9: 17.07ms - 27.09ms<br>Number of _sleep falling behind_ events: 1
GRPC Istio-meshed at 1500 qps    | http://ld2.isim.me/?s=grpc_istio_1500qps_10s    | Duration: 10s<br>qps: 1500<br>Concurrent connections: 4<br>p99.9: 16.63ms - 19.58ms<br>Number of _sleep falling behind_ events: 20
GRPC Istio-meshed at 2000 qps    | http://ld2.isim.me/?s=grpc_istio_2000qps_10s    | Duration: 10s<br>qps: 2000<br>Concurrent connections: 4<br>p99.9: 16.29ms - 19.26ms<br>Number of _sleep falling behind_ events: 19

Other interesting charts:

Test Suite                         | URL
-----------------------------------| -----------------------------------
HTTP baseline for all qps          | http://ld2.isim.me/?s=http_baseline
HTTP Linkerd2-meshed for all qps   | http://ld2.isim.me/?s=http_linkerd
HTTP Istio-meshed for all qps      | http://ld2.isim.me/?s=http_istio
GRPC baseline for all qps          | http://ld2.isim.me/?s=grpc_baseline
GRPC Linkerd2-meshed for all qps   | http://ld2.isim.me/?s=grpc_linkerd
GRPC Istio-meshed for all qps      | http://ld2.isim.me/?s=grpc_istio

With 4 concurrent connections, the _sleep falling behind_ warnings are observable in tests with at least 1000 qps. According to the Fortio [FAQ](https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass), this warning signifies that fortio and the system can't sustain that qps, divided equally across the requested number of connections. Most of the sleep warnings are associated with the Istio-meshed echo servers.

All the report logs can be found in the same [reports/gke](report/gke) folder.
