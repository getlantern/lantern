keyman [![Travis CI Status](https://travis-ci.org/getlantern/keyman.svg?branch=master)](https://travis-ci.org/getlantern/keyman)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/keyman/badge.png)](https://coveralls.io/r/getlantern/keyman)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/keyman?status.png)](http://godoc.org/github.com/getlantern/keyman)
======

Easy golang RSA key and certificate management. 

API documentation available on [godoc](https://godoc.org/github.com/getlantern/keyman).

### Build Notes

On Windows, keyman uses a custom executable for importing certificates into the
system trust store.  This executable is built using Visual Studio from this
[solution](certimporter).

The resulting executable is packaged into go using
[go-bindata](https://github.com/jteeuwen/go-bindata) by running the below
command inside the [certimporter](certimporter) folder:

```bash
go-bindata -nomemcopy -nocompress -prefix Release -o ./certimporter.go -pkg certimporter Release
```

Note the use of `-nocompress` - we do this so that the resulting executable can
be more efficiently binary diffed.  When distributing a full executable, it will
be compressed for distribution anyway, so there's no point to compressing the
embedded certimporter.exe.
