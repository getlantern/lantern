# HTTP Proxy in Go

[![Build Status](https://travis-ci.org/getlantern/http-proxy.svg?branch=master)](https://travis-ci.org/getlantern/http-proxy)

## Run

[Custom fork of Go](https://github.com/getlantern/go/tree/lantern) is
currently required. We'll eventually switch to Go 1.7 which supports what we
need due to [this](https://github.com/golang/go/issues/13998).

First get dependencies:

```
go get -t
```

Then run with:

```
go run http_proxy.go
```

## Build your own Proxy

This proxy is built around the classical *Middleware* pattern.  You can see examples in the `forward` and `httpconnect` packges.  They can be chained together forming a series of filters.

See this code snippet:

``` go
// Middleware: Forward HTTP Messages
forwarder, err := forward.New(nil, forward.IdleTimeoutSetter(time.Duration(*idleClose)*time.Second))
if err != nil {
	log.Error(err)
}

// Middleware: Handle HTTP CONNECT
httpConnect, err := httpconnect.New(forwarder, httpconnect.IdleTimeoutSetter(time.Duration(*idleClose)*time.Second))
if err != nil {
	log.Error(err)
}

...
```

Additionally, this proxy uses the concept of *connection wrappers*, which work as a series of wrappers over the listeners generating the connections, and the connections themselves.

The following is an extract of the default listeners you can find in this proxy.  You need to provide functions that take the previous listener and produce a new one, wrapping it in the process.  Note that the generated connections must implement `StateAwareConn`.  See more examples in `listeners`.

``` go
srv.AddListenerWrappers(
	// Limit max number of simultaneous connections
	func(ls net.Listener) net.Listener {
		return listeners.NewLimitedListener(ls, *maxConns)
	},

    // Close connections after 30 seconds of no activity
	func(ls net.Listener) net.Listener {
		return listeners.NewIdleConnListener(ls, time.Duration(*idleClose)*time.Second)
	},
)
```


## Test

### Run tests

```
go test
```

Use this for verbose output:

```
TRACE=1 go test
```

### Manual testing

*Keep in mind that cURL doesn't support tunneling through an HTTPS proxy, so if you use the -https option you have to use other tools for testing.

Run the server as follows:

```
go run http_proxy.go
```

Test direct proxying with cURL:

```
curl -kvx localhost:8080 http://www.google.com/humans.txt
curl -kvx localhost:8080 https://www.google.com/humans.txt
```

Test HTTP connect with cURL:

```
curl -kpvx localhost:8080 http://www.google.com/humans.txt
curl -kpvx localhost:8080 https://www.google.com/humans.txt
```
