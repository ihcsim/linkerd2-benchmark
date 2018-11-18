# Report
This report contains the summarized result of my load tests in a GKE environment. The report charts can be viewed at http://ld2.isim.me

## Environment Set-up
The [script](../../gke_stress.sh) used in this experiment runs Istio 1.0.3, Linkerd2 edge-18.11.1 and Fortio 1.3.1 on a GKE 1.11.2-gke.18 cluster. It stress-tests the Fortio echo servers by using the Fortio load genertor to repeatedly send HTTP and GRPC request loads to the baseline, Linkerd2-meshed and Istio-meshed echo servers.

The script starts with a test suite consisting of 10 test runs with a 120 qps (queries/sec) rate. Each test run is made up of a 10-second load of HTTP requests, follows by a 10-second load of GRPC requests. IOW, each test suite stresses an echo server for a total of 200 seconds at the predefined qps rate. There are 2 echo servers in each namespace. The next test suite runs at a 500 qps rate. All subsequent test suites have a 500-qps increase in its traffic rate until the final test suite which runs at 2000 qps.

In addition to measuring the response time, I am also interested to see at what qps rate does the load generator starts to issue _sleep_ events when it detects the echo servers can no longer keep up with the load.

The GKE cluster is comprised of the following node pools:

* `system`: A single node of `n1-standard-2` type to host the `kube-system`, `linkerd` and `istio-system` namespaces.
* `baseline`: A single node of `n1-standard-1` type to host the baseline echo servers. The node is tainted with the `app-family: baseline` taint. 2 echo server pods are deployed to this namespace.
* `linkerd-meshed`: A single node of `n1-standard-1` type to host the Linkerd2-meshed echo servers. The node is tainted with the `app-family: linkerd-meshed` taint. 2 echo server pods are deployed to this namespace.
* `istio-meshed`: A single node of `n1-standard-1` type to host the Istio-meshed echo servers. The node is tainted with the `app-family: istio-meshed` taint. 2 echo server pods are deployed to this namespace.
* `load-generator`: A single node of `n1-standard-1` type to host the load generator. The node is tainted with the `app-family: load-generator` taint.

The Istio control plane is installed based on the recommended Helm-based production installation instructions found [here](https://istio.io/docs/setup/kubernetes/helm-install/).

## How To Read The Charts
Navigate to http://ld2.isim.me

* To view the histogram of a single test run, select its label from the list.
* To compare the results of multiple test runs, hold down your SHIFT key while selecting their labels.
* The filter text field can be used to facilitate more detailed comparisons between the test runs.
  * For example, to view the test result of all the 120 qps HTTP tests on the baseline echo servers, enter _http_baseline_120qps_ in the filter and hit ENTER.

Note that:

* The vertical axis represents a single test run of 100 qps over a period of 10 seconds.
* The top black line indicates the qps rate. A dip in this line indicates a sleep event that occurs because Fortio and your machine can't sustain the qps divided equally across the requested number of connections.
* Each dot on the colored lines represents the min, median, max and different percentiles latencies.
* The legend of the chart can be clicked to include/exclude certain data.

### HTTP Tests


### GRPC Tests


### Resource Utilization
