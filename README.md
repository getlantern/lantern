flashlight-build [![Travis CI Status](https://travis-ci.org/getlantern/flashlight-build.svg?branch=devel)](https://travis-ci.org/getlantern/flashlight-build)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/flashlight-build/badge.png?branch=devel)](https://coveralls.io/r/getlantern/flashlight-build)
==========

flashlight-build is a [gost](https://github.com/getlantern/gost) project that
provides repeatable builds and consolidated pull requests for flashlight.

### Building Flashlight

Flashlight requires [Go 1.4.x](http://golang.org/dl/).

It is convenient to build flashlight for multiple platforms using
[gox](https://github.com/mitchellh/gox).

The typical cross-compilation setup doesn't work for anything that uses C code,
which includes the DNS resolution code and some other things.  See
[this blog](https://inconshreveable.com/04-30-2014/cross-compiling-golang-programs-with-native-libraries/)
for more discussion.

To deal with that, you need to use a Go installed using
[gonative](https://github.com/getlantern/gonative). Ultimately, you can put this
go wherever you like. Ox keeps his at ~/go_native.

```bash
go get github.com/mitchellh/gox
go get github.com/getlantern/gonative
cd ~
gonative build -version="1.4" -platforms="darwin_amd64 linux_386 linux_amd64 windows_386"
mv go go_native
```

Finally update your GOROOT and PATH to point at `~/go_native` instead of your
previous go installation.  They should look something like this:

```bash
➜  flashlight git:(1606) ✗ echo $GOROOT
/Users/ox.to.a.cart//go_native
➜  flashlight git:(1606) ✗ which go
/Users/ox.to.a.cart//go_native/bin/go
```

Now that you have go and gox set up, the binaries used for Lantern can be built
with the `./crosscompile.bash` script. This script also sets the version of
flashlight to the most recent commit id in git, or if the most recent commit is
tagged, the tag of that commit id.

An annotated tag can be added like this:

```bash
git tag -a v1.0.0 -m"Tagged 1.0.0"
git push --tags
```

The script `tagandbuild.bash` tags and runs crosscompile.bash.

`./tagandbuild.bash <tag>`

Note - ./crosscompile.bash omits debug symbols to keep the build smaller.

Note also that these binaries should  be signed for use in production, at least
on OSX and Windows. On OSX the command to do this should resemble the following
(assuming you have an associated code signing certificate):

```
codesign -s "Developer ID Application: Brave New Software Project, Inc" -f install/osx/pt/flashlight/flashlight
```

The script `copyexecutables.bash` takes care of signing the OS X executable and
copying everything in the Lantern file tree.

`copyexecutables.bash` will also optionally sign the Windows executable if the
environment variables BNS_CERT and BNS_CERT_PASS are set to point to
[bns-cert.p12](https://github.com/getlantern/too-many-secrets/blob/master/bns_cert.p12)
and its [password](https://github.com/getlantern/too-many-secrets/blob/master/build-installers/env-vars.txt#L3).

The code signing [certificate](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12)
and [password](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12.txt)
can be obtained from [too-many-secrets](https://github.com/getlantern/too-many-secrets).

note - Signing windows code requires that the
[osslsigncode](http://sourceforge.net/projects/osslsigncode/) utility be
installed. On OS X with homebrew, you can do this with
`brew install osslsigncode`.

### Continuous Integration with Travis CI
Continuous builds are run on Travis CI. These builds use the `.travis.yml`
configuration.  The github.com/getlantern/cf unit tests require an envvars.bash
to be populated with credentials for cloudflare. The original `envvars.bash` is
available [here](https://github.com/getlantern/too-many-secrets/blob/master/envvars.bash).
An encrypted version is checked in as `envvars.bash.enc`, which was encrypted
per the instructions [here](http://docs.travis-ci.com/user/encrypting-files/).


