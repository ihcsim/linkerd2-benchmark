# Linkerd2 Benchmarko
This project contains artifacts to perform load tests on [Linkerd2](https://linkerd.io/). [Fortio](https://fortio.org/) is used as both the load generator and the echo servers because of its lightweight footprint, support of HTTP, HTTP2, GRPC and TLS. Its echo server also has minimal dependencies. For more information on Fortio (includings its difference with [wrk](https://github.com/wg/wrk)), refer to this [FAQ](https://github.com/fortio/fortio/wiki/FAQ#i-want-to-get-the-best-results-what-flags-should-i-pass).

## Docker
The `docker.sh` creates a local Docker network of 3 containers of 2 echo servers and 1 load generator. The load generator sends HTTP and GRPC load to both echo servers. This script doesn't install Linkerd2. The reports are stored in the `reports` folder.

This is the list of software needed to run this script:

* [Docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
* [Fortio v1.3.0](https://github.com/fortio/fortio)

Usage:
```
# see usage
$ docker.sh -h

# set up the Docker containers and run the load tests.
# all JSON reports will be saved in the 'reports/' folder by default
$ INIT=true ./docker.sh

# to view the sample reports locally at localhost:8080
$ fortio report -data-dir reports/docker.sh/samples
```
Specify the `INIT` variable to re-create all containers, volumes, network and reports.
