go-igdman [![Travis CI Status](https://travis-ci.org/getlantern/go-igdman.svg?branch=master)](https://travis-ci.org/getlantern/go-igdman)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/go-igdman/badge.png)](https://coveralls.io/r/getlantern/go-igdman)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/go-igdman?status.png)](http://godoc.org/github.com/getlantern/go-igdman)
==========
To install:

`go get github.com/getlantern/go-igdman`

For docs:

[`godoc github.com/getlantern/go-igdman/igdman`](https://godoc.org/github.com/getlantern/go-igdman/igdman)

Acknowledgements:

igdman is just a wrapper around:

- [miniupnpc](https://github.com/miniupnp/miniupnp)
- [go-nat-pmp](https://github.com/jackpal/go-nat-pmp/)

## Embedding upnpc

To build the go files that embed the upnpc executables for different platforms,
just place the binaries into the right subfolder of `binaries` and then run
`embedupnpc.bash`. This script takes care of code signing the ~~Windows and~~
OS X executables.

~~This script signs the Windows executable, which requires that
[osslsigncode](http://sourceforge.net/projects/osslsigncode/) utility be
installed. On OS X with homebrew, you can do this with
`brew install osslsigncode`.~~

~~You will also need to set the environment variables BNS_CERT and BNS_CERT_PASS
to point to [bns-cert.p12](https://github.com/getlantern/too-many-secrets/blob/master/bns_cert.p12)
and its [password](https://github.com/getlantern/too-many-secrets/blob/master/build-installers/env-vars.txt#L3)
so that the script can sign the Windows executable.~~

This script also signs the OS X executable, which requires you to use our OS X
signing certificate, available [here](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12).
The password is [here](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12.txt).