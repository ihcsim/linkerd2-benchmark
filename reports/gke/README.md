# Report
This report contains the summarized result of my load tests in a GKE environment. The report charts can be viewed at http://ld2.isim.me

## Environment Set-up
The [script](../../gke_stress.sh) used in this experiment runs Istio 1.0.3, Linkerd2 edge-18.11.1 and Fortio 1.3.1 on a GKE 1.11.2-gke.18 cluster. It stress-tests the Fortio echo servers by using the Fortio load genertor to repeatedly send HTTP and GRPC request loads to the baseline, Linkerd2-meshed and Istio-meshed echo servers.

The script starts with a test suite consisting of 10 test runs. Each test run is made up of a 10-second load of HTTP requests, follows by a 10-second load of GRPC requests, at a rate of 120 qps (queries/sec). IOW, each test suite stresses an echo server for a total of 200 seconds at the predefined qps rate. There are 2 echo servers in each namespace. The next test suite runs at a 500 qps rate. All subsequent test suites have a 500-qps increase in its traffic rate until the final test suite which runs at 2000 qps.

In addition to measuring the response time, I am also interested to see at what qps rate does the load generator starts to issue _sleep_ events when it detects the echo servers can no longer keep up with the load.

The GKE cluster is comprised of the following node pools:

Node Pool Name   | Machine Type  | k8s Namespace                            | Node Taint                   | # of Echo Servers
---------------- | ------------- | ---------------------------------------- | ---------------------------- | -----------------
`system`         | n1-standard-2 | `kube-system`, `linkerd`, `istio-system` | None                         | 0
`baseline`       | n1-standard-1 | `benchmark-baseline`                     | `app-family: baseline`       | 2
`linkerd-meshed` | n1-standard-1 | `benchmark-linkerd2`                     | `app-family: linkerd-meshed` | 2
`istio-meshed`   | n1-standard-1 | `benchmark-istio`                        | `app-family: istio-meshed`   | 2
`load-generator` | n1-standard-1 | `benchmark-load`                         | `app-family: load-generator` | 0

The Istio control plane is installed based on the recommended Helm-based production installation instructions found [here](https://istio.io/docs/setup/kubernetes/helm-install/).

## How To Read The Charts
Navigate to http://ld2.isim.me

* To view the histogram of a single test run, select its label from the list.
* To compare the results of multiple test runs, hold down your SHIFT key while selecting their labels.
* The filter text field can be used to facilitate more detailed comparisons between the test runs.
  * For example, to view the test result of all the 120 qps HTTP tests on the baseline echo servers, enter _http_baseline_120qps_ in the filter and hit ENTER.

Note that:

* The vertical axis represents a single test run of the pre-defined qps over a period of 10 seconds.
* The legend of the chart can be clicked to include/exclude certain data.
* The usage of the dual y-axes is [confusing](https://blog.datawrapper.de/dualaxis/).
  * Each dot on the colored lines corresponds to the primary (left) y-axis, representing the min, median, max and different percentiles latencies.
  * The top black line corresponds to the secondary (right) y-axis, indicating the qps rate.

## Trends
Most of the outliers seem to be caused by the max and p99.9 measurements. Disabling them to see the more consistent p99 measurements.

Test Suite                            | Filter        | Remark
------------------------------------- | --------------| ------
All HTTP test results                 | http          |
All baseline HTTP test results        | http_baseline |
All Linkerd2-meshed HTTP test results | http_linkerd  |
All Istio-meshed HTTP test results    | http_istio    |
All GRPC test results                 | grpc          |
All baseline GRPC test results        | grpc_baseline |
All Linkerd2-meshed GRPC test results | grpc_linkerd  |
All Istio-meshed GRPC test results    | grpc_istio    |

The following filters provide more granular test results.

Test Suite                         | Filter           | Remark
---------------------------------- | ---------------- | ------
Baseline HTTP load at N qps        | http_baseline_N  |
Linkerd2-meshed HTTP load at N qps | http_linkerd_N   |
Istio-meshed HTTP load at N qps    | http_istio_N     |
Baseline GRPC load at N qps        | grpc_baseline_N  |
Linkerd2-meshed GRPC load at N qps | grpc_linkerd_N   |
Istio-meshed GRPC load at N qps    | grpc_istio_N     |

### Resource Utilization
