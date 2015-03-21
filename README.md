flashlight-build [![Travis CI Status](https://travis-ci.org/getlantern/flashlight-build.svg?branch=devel)](https://travis-ci.org/getlantern/flashlight-build)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/flashlight-build/badge.png?branch=devel)](https://coveralls.io/r/getlantern/flashlight-build)
==========

flashlight-build is a [gost](https://github.com/getlantern/gost) project that
provides repeatable builds and consolidated pull requests for flashlight (now
lantern).  **It's very important to read the gost documentation thoroughly in
order to build this project.**

### Building Flashlight

Flashlight requires [Go 1.4.x](http://golang.org/dl/).

You will also need [npm](https://www.npmjs.com/).

It is convenient to build flashlight for multiple platforms using
[gox](https://github.com/mitchellh/gox).

The typical cross-compilation setup doesn't work for anything that uses C code,
which includes the DNS resolution code and some other things.  See
[this blog](https://inconshreveable.com/04-30-2014/cross-compiling-golang-programs-with-native-libraries/)
for more discussion.

To deal with that, you need to use a Go installed using
[gonative](https://github.com/getlantern/gonative). Ultimately, you can put this
go wherever you like, such as at ~/go_native.

To set this all up, you should run the following:

Note - we're using a fork of inconshreveable/gonative because of
[this problem](https://github.com/inconshreveable/gonative/pull/7).

```bash
go get github.com/getlantern/gost
go get github.com/mitchellh/gox
go get github.com/getlantern/gonative
cd ~
gonative build -version="1.4.1" -platforms="darwin_amd64 linux_386 linux_amd64 windows_386"
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

If the environemnt variable `UPDATE_DIST=true` is set, `./crosscompile.bash`
also updates the resources in the dist folder.

An annotated tag can be added like this:

```bash
git tag -a v1.0.0 -m"Tagged 1.0.0"
git push --tags
```

The script `tagandbuild.bash` tags and runs crosscompile.bash.

`./tagandbuild.bash <tag>`

Note - ./crosscompile.bash omits debug symbols to keep the build smaller.

Note - tagandbuild.bash requires the BNS_CERT and BNS_CERT_PASS environment
variables to sign the windows executable. See Packaging for Windows below.

### Building on Linux

Cross-compilation targeting Linux is currently not supported, so Linux releases
need to be built on Linux.  There are some build prerequisites that you can pick
up with:

See https://github.com/getlantern/lantern/issues/2235.

`sudo apt-get install libgtk-3-dev libappindicator3-dev`

### Building at Development Time

At development time, you might use `go install github.com/getlantern/flashlight`
or `go build github.com/getlantern/flashlight`. If you do this after using
`crosscompile.bash` you might get an error like this:

> ld: warning: ignoring file /var/folders/j_/9dywssj524gf3100s4q9l48w0000gp/T//go-link-LUd0tc/000000.o, file was built for unsupported file format ( 0x4C 0x01 0x01 0x00 0x00 0x00 0x00 0x00 0x2C 0xFD 0x01 0x00 0x01 0x00 0x00 0x00 ) which is not the architecture being linked (x86_64): /var/folders/j_/9dywssj524gf3100s4q9l48w0000gp/T//go-link-LUd0tc/000000.o

You can avoid this by using `CGO_ENABLED=1 go install`.

### Packaging for OS X
Lantern on OS X is packaged as the `Lantern.app` app bundle, distributed inside
of a drag-and-drop dmg installer. The app bundle and dmg can be created using
`./package_osx.bash`.

This script requires that you have [nodejs](http://nodejs.org/) installed.

The script takes a single parameter, which is the version string to display in
the installer background, for example:

```bash
./package_osx.bash 2.0.0_beta1
```

`./package_osx.bash` signs the Lantern.app using the BNS code signing
certificate in your KeyChain. The [certificate](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12)
and [password](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12.txt)
can be obtained from [too-many-secrets](https://github.com/getlantern/too-many-secrets).

If signing fails, the script will still build the app bundle and dmg, but the
app bundle won't be signed. Unsigned app bundles can be used for testing but
should never be distributed to end users.

The background image for the DMG is `dmgbackground.png` and the icon is in
`lantern.icns`.

### Packaging for Windows
Lantern on Windows is distributed as an installer built with
[nsis](http://nsis.sourceforge.net/). The installer is built and signed with
./package_win.bash.

Signing windows code requires that the
[osslsigncode](http://sourceforge.net/projects/osslsigncode/) utility be
installed. On OS X with homebrew, you can do this with
`brew install osslsigncode`.

The script takes a single parameter, which is the version string to display in
the Add/Remove programs control panel.

For `./package_win.bash` to be able to sign the executable, the environment
varaibles BNS_CERT and BNS_CERT_PASS must be set to point to
[bns-cert.p12](https://github.com/getlantern/too-many-secrets/blob/master/bns_cert.p12)
and its [password](https://github.com/getlantern/too-many-secrets/blob/master/build-installers/env-vars.txt#L3).
You can set the environment variables and run the script on one line, like this:

`BNS_CERT=<cert> BNS_CERT_PASS=<pass> ./package_win.bash 2.0.0_beta1`

### Packaging for Ubuntu
Lantern on Ubuntu is distributed as a .deb package.  After you have built
a Lantern executable with `./linuxcompile.bash`, you can package it with
`./package_ubuntu.bash <version>`.  The version string must match the Debian
requirements:

https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version

This will build a 64bit package if run on a 64bit system and will build a 32bit
package if run on a 32bit system.

### Updating Icons

The icons used for the system tray are stored in
src/github/getlantern/flashlight/icons. To apply changes to the icons, make your
updates in the icons folder and then run `./udpateicons.bash`.

### Continuous Integration with Travis CI
Continuous builds are run on Travis CI. These builds use the `.travis.yml`
configuration.  The github.com/getlantern/cf unit tests require an envvars.bash
to be populated with credentials for cloudflare. The original `envvars.bash` is
available [here](https://github.com/getlantern/too-many-secrets/blob/master/envvars.bash).
An encrypted version is checked in as `envvars.bash.enc`, which was encrypted
per the instructions [here](http://docs.travis-ci.com/user/encrypting-files/).


