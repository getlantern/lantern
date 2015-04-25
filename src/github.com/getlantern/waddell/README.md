waddell [![Travis CI Status](https://travis-ci.org/getlantern/waddell.svg?branch=master)](https://travis-ci.org/getlantern/waddell)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/waddell/badge.png)](https://coveralls.io/r/getlantern/waddell)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/waddell?status.png)](http://godoc.org/github.com/getlantern/waddell)
==========
waddell provides a simple signaling TCP-based signaling service.  It includes
a server API for implementing a server, as well as a client API for talking to
waddell servers. The server optionally supports running with TLS, using pk and
cert files specified at the command-line.

To install:

`go get github.com/getlantern/waddell`

For docs:

[`godoc github.com/getlantern/waddell`](https://godoc.org/github.com/getlantern/waddell)