tlsdialer [![Travis CI Status](https://travis-ci.org/getlantern/tlsdialer.svg?branch=master)](https://travis-ci.org/getlantern/tlsdialer)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/tlsdialer/badge.png)](https://coveralls.io/r/getlantern/tlsdialer)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/tlsdialer?status.png)](http://godoc.org/github.com/getlantern/tlsdialer)
==========
package tlsdialer contains a customized version of crypto/tls.Dial that allows
control over whether or not to send the ServerName extension in the client
handshake.

v2 is the current version.  Import and doc information on
[gopkg.in](http://gopkg.in/getlantern/tlsdialer.v2).