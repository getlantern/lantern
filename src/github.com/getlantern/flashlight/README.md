flashlight [![Travis CI Status](https://travis-ci.org/getlantern/flashlight.svg?branch=master)](https://travis-ci.org/getlantern/flashlight)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/flashlight/badge.png)](https://coveralls.io/r/getlantern/flashlight)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/flashlight?status.png)](http://godoc.org/github.com/getlantern/flashlight)
==========

**WARNING**: The flashlight server will refuse to serve domain fronted traffic
through most non-censored countries.  See 
https://github.com/getlantern/flashlight-build/pull/141 for more details.

Lightweight host-spoofing web proxy written in go.

flashlight runs in one of two modes:

client - meant to run locally to wherever the browser is running, forwards
requests to the server

server - handles requests from a flashlight client proxy and actually proxies
them to the final destination

Using CloudFlare (and other CDNS), flashlight has the ability to masquerade as
running on a different domain than it is.  The client simply specifies the
"masquerade" flag with a value like "thehackernews.com".  flashlight will then
use that masquerade host for the DNS lookup and will also specify it as the
ServerName for SNI (though this is not actually necessary on CloudFlare). The
Host header of the HTTP request will actually contain the correct host
(e.g. getiantem.org), which causes CloudFlare to route the request to the
correct host.

Flashlight uses [enproxy](https://github.com/getlantern/enproxy) to encapsulate
data from/to the client as http request/response pairs.  This allows it to
tunnel regular HTTP as well as HTTPS traffic over CloudFlare.  In fact, it can
tunnel any TCP traffic.

### Usage

```bash
Usage of flashlight:
  -addr="": ip:port on which to listen for requests. When running as a client proxy, we'll listen with http, when running as a server proxy we'll listen with https (required)
  -cloudconfig="": optional http(s) URL to a cloud-based source for configuration updates
  -cloudconfigca="": optional PEM encoded certificate used to verify TLS connections to fetch cloudconfig
  -configaddr="": if specified, run an http-based configuration server at this address
  -configdir="": directory in which to store configuration, including flashlight.yaml (defaults to current directory)
  -country="xx": 2 digit country code under which to report stats. Defaults to xx.
  -cpuprofile="": write cpu profile to given file
  -frontfqdns="": YAML string representing a map from the name of each front provider to a FQDN that will reach this particular server via that provider (e.g. '{cloudflare: fl-001.getiantem.org, cloudfront: blablabla.cloudfront.net}')
  -headless=false: if true, lantern will run with no ui
  -help=false: Get usage help
  -httptest.serve="": if non-empty, httptest.NewServer serves on this address and blocks
  -instanceid="": instanceId under which to report stats to statshub. If not specified, no stats are reported.
  -memprofile="": write heap profile to given file
  -parentpid=0: the parent process's PID, used on Windows for killing flashlight when the parent disappears
  -portmap=0: try to map this port on the firewall to the port on which flashlight is listening, using UPnP or NAT-PMP. If mapping this port fails, flashlight will exit with status code 50
  -proxyall=false: set to true to proxy all traffic through Lantern network
  -registerat="": base URL for peer DNS registry at which to register (e.g. https://peerscanner.getiantem.org)
  -role="": either 'client' or 'server' (required)
  -statshub="pure-journey-3547.herokuapp.com": address of statshub server
  -statsperiod=0: time in seconds to wait between reporting stats. If not specified, stats are not reported. If specified, statshub, instanceid and statshubAddr must also be specified.
  -test.bench="": regular expression to select benchmarks to run
  -test.benchmem=false: print memory allocations for benchmarks
  -test.benchtime=1s: approximate run time for each benchmark
  -test.blockprofile="": write a goroutine blocking profile to the named file after execution
  -test.blockprofilerate=1: if >= 0, calls runtime.SetBlockProfileRate()
  -test.coverprofile="": write a coverage profile to the named file after execution
  -test.cpu="": comma-separated list of number of CPUs to use for each test
  -test.cpuprofile="": write a cpu profile to the named file during execution
  -test.memprofile="": write a memory profile to the named file after execution
  -test.memprofilerate=0: if >=0, sets runtime.MemProfileRate
  -test.outputdir="": directory in which to write profiles
  -test.parallel=1: maximum test parallelism
  -test.run="": regular expression to select tests and examples to run
  -test.short=false: run smaller test suite to save time
  -test.timeout=0: if positive, sets an aggregate time limit for all tests
  -test.v=false: verbose: print additional output
  -uiaddr="": if specified, indicates host:port the UI HTTP server should be started on
  -unencrypted=false: set to true to run server in unencrypted mode (no TLS)
```

Example Client:

```bash 
./flashlight -addr localhost:10080 -role client
```

Example Server:

```bash
./flashlight -addr :443 -role server
```

Example Curl Test:

```bash
curl -x localhost:10080 http://www.google.com/humans.txt
Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.
```

On the client, you should see something like this for every request:

```bash
Handling request for: http://www.google.com/humans.txt
```

### Configuration Management

Please refer to [Genconfig](genconfig/README.md)
