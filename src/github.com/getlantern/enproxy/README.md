enproxy [![Travis CI Status](https://travis-ci.org/getlantern/enproxy.svg?branch=master)](https://travis-ci.org/getlantern/enproxy)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/enproxy/badge.png)](https://coveralls.io/r/getlantern/enproxy)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/enproxy?status.png)](http://godoc.org/github.com/getlantern/enproxy)
==========

enproxy provides an implementation of net.Conn that sends and receives data to/
from a proxy using HTTP request/response pairs that encapsulate the data.  This
is useful when you need to tunnel arbitrary protocols over an HTTP proxy that
doesn't support HTTP CONNECT.  Content distribution networks are one example of
such a proxy.

To open such a connection:

```go
conn := &enproxy.Conn{
  Addr:   addr,
  Config: &enproxy.Config{
    DialProxy: func(addr string) (net.Conn, error) {
      // This opens a TCP connection to the proxy
      return net.Dial("tcp", proxyAddress)
    },
    NewRequest: func(method string, body io.Reader) (req *http.Request, err error) {
      // This is called for every request from enproxy.Conn to the proxy
      return http.NewRequest(method, "http://"+proxyAddress+"/", body)
    },
  },
}
err := conn.Connect()
if err == nil {
  // start using conn as any other net.Conn
}
```

To start the corresponding proxy server:

```go
proxy := &enproxy.Proxy{}
err := proxy.ListenAndServe(proxyAddress)
if err != nil {
  log.Fatalf("Unable to listen and serve: %s", err)
}
```

## Debugging

enproxy allows tracing various global metrics about connections, which can be
useful when debugging issues like file descriptor leaks. To enable this tracing,
just set the environment variable `TRACE_CONN_STATE=true`. This will cause the
program to output information like the below every 5 seconds:

```
---- Connections----
Open:                        34
Closing:                      0
Blocked on Closing:           0
Blocked on Read:             33
Reading:                     33
Reading Finishing:            0
Blocked on Write:             0
Writing:                     33
  Selecting:                 33
  Writing:                    0
    Write Pipe Open:          0
    Request Pending:          0
      Submitting Req.:        0
      Processing Req.:        1
        Posting Req. Fin:     0
        Posting Resp:         0       
        Dialing First:        0
        Redialing:            0
    Doing Write:              0
  Posting Response:           0
  Writing Empty:              0
  Finishing Body:             0
  Finishing:                  0
Requesting:                  33
Requesting Finishing:         0
```