flashlight [![Travis CI Status](https://travis-ci.org/getlantern/flashlight.svg?branch=master)](https://travis-ci.org/getlantern/flashlight)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/flashlight/badge.png)](https://coveralls.io/r/getlantern/flashlight)&nbsp;[![GoDoc](https://godoc.org/github.com/getlantern/flashlight?status.png)](http://godoc.org/github.com/getlantern/flashlight)
==========

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
  -help=false: Get usage help
  -instanceid="": instanceId under which to report stats to statshub. If not specified, no stats are reported.
  -memprofile="": write heap profile to given file
  -parentpid=0: the parent process's PID, used on Windows for killing flashlight when the parent disappears
  -portmap=0: try to map this port on the firewall to the port on which flashlight is listening, using UPnP or NAT-PMP. If mapping this port fails, flashlight will exit with status code 50
  -role="": either 'client' or 'server' (required)
  -server="": FQDN of flashlight server when running in server mode (required)
  -statsaddr="": host:port at which to make detailed stats available using server-sent events (optional)
  -statshub="pure-journey-3547.herokuapp.com": address of statshub server
  -statsperiod=0: time in seconds to wait between reporting stats. If not specified, stats are not reported. If specified, statshub, instanceid and statsaddr must also be specified.
  -waddelladdr="": if specified, connect to this waddell server and process NAT traversal requests inbound from waddell
  -waddellcert="": if specified, use this cert (PEM-encoded) to authenticate connections to waddell.  Otherwise, a default certificate is used.
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

### Building

Flashlight requires [Go 1.3.x](http://golang.org/dl/).

It is convenient to build flashlight for multiple platforms using
[gox](https://github.com/getlantern/gox).

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
gonative -version="1.3.3" -platforms="darwin_amd64 linux_386 linux_amd64 windows_386"
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
flashlight to the most recent annotated tag in git. An annotated tag can be
added like this:

```bash
git tag -a v1.0.0 -m"Tagged 1.0.0"
git push --tags
```

The script `tagandbuild.bash` tags and runs crosscompile.bash.

`./tagandbuild.bash <tag>`

Note - ./crosscompile.bash omits debug symbols to keep the build smaller.

Note also that these binaries should also be signed for use in production, at
least on OSX and Windows. On OSX the command to do this should resemble the
following (assuming you have an associated code signing certificate):

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

### Masquerade Host Management

Masquerade host configuration is managed using utilities in the [`genconfig/`](genconfig/) subfolder.

#### Setup

You need the s3cmd tool installed and set up.  To install on
Ubuntu:

```bash
sudo apt-get install s3cmd
```

On OS X:
```bash
brew install s3cmd
```

And then run `s3cmd --configure` and follow the on-screen instructions.  You
can get AWS credentials that are good for uploading to S3 in
[too-many-secrets/lantern_aws/aws_credential](https://github.com/getlantern/too-many-secrets/blob/master/lantern_aws/aws_credential).

#### Managing masquerade hosts

The file domains.txt contains the list of masquerade hosts we use, and
blacklist.txt contains a list of blacklisted domains that we exclude even if
present in domains.txt.

To alter the list of domains or blacklist:

1. Edit [`domains.txt`](genconfig/domains.txt) and/or [`blacklist.txt`](genconfig/blacklist.txt)
2. `go run genconfig.go -domains domains.txt -blacklist blacklist.txt`.
3. Commit the changed [`masquerades.go`](config/masquerades.go) and [`cloud.yaml`](genconfig/cloud.yaml) to git if you want.
4. Upload cloud.yaml to s3 using [`udpateyaml.bash`](genconfig/updateyaml.bash) if you want.
