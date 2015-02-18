# _test_app

This is an example application that prints the version of the running program
and the executable file's version in a loop. The purpose of this example is to
demonstrate how to use `github.com/getlantern/autoupdate` and the `equinox`
backend.

## Instructions

[Sign up](https://equinox.io/user/signup) for [equinox.io][1].

Create a new application using the equinox
[dashboard](https://equinox.io/dashboard).

Identify the **Account ID**, **Secret Key** and the new application's
**Application ID**

Install the Lantern's releasetool:

```sh
go install github.com/getlantern/autoupdate/releasetool
releasetool
# Usage of releasetool:
#  -arch="": Build architecture. (amd64|386|arm)
#  -channel="stable": Release channel.
#  -config="equinox.yaml": Configuration file.
#  -os="": Operating system. (linux|windows|darwin)
#  -source="": Source binary file.
#  -version=-1: Version number.
```

We are going to sign our releases, this signature is different from the
signatures required by OSX and Windows and it's only used to validate the
integrity of our releases.

If you don't have a keypair already, you can create a new one using `openssl`:

```sh
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -out public.pem -pubout
```

Add a new entry for the application inside `config.go` that resembles the
following map:

```go
// config.go

var configMap = map[string]*config{
  // ...
  // "_test_app" will be used as the internal name of the application.
	"_test_app": &config{
		appID:         `ap_ZZZ`,
		updateChannel: `stable`,
		publicKey:     []byte("-----BEGIN PUBLIC KEY-----\nABCDEF\n-----END PUBLIC KEY-----\n"),
	},
  // ...
}
```

Create an `equinox.yaml` file and store some values that `releasetool` is going
to use:

```yaml
account_id: id_XXX
secret_key: key_YYY
application_id: ap_ZZZ
channel: stable
private_key: ./private.pem
```

Use the `releasetool` CLI to update and publish a new binary release.

```sh
go build -o main.v1
releasetool -config equinox.yaml -arch amd64 -os darwin -version 1 -channel stable -source main.v1
# ...
```

You may sign the executable with codesign or osslsigncode before using
`releasetool`.

## How to test the autoupdate package?

In order to actually test automatic updates, we are going to manually increase
the version of main.go, compile a new binary and upload it to equinox.

You should already have a `main.v1` compiled binary, if not, create it:

```
go build -o main.v1
```

And upload it to equinox:

```
releasetool -config equinox.yaml -arch amd64 -os darwin -version 1 -channel stable -source main.v1
```

Increase `internalVersion` constant to 2 and repeat:

```sh
grep internalVersion main.go | head -n 1
#        internalVersion = 2
go build -o main.v2
releasetool ... -version 2 -source main.v2
```

Do it again for version 3.

```sh
grep internalVersion main.go | head -n 1
#        internalVersion = 3
go build -o main.v3
releasetool ... -version 3 -source binary.file
```

Copy the original `main.v1` to `main`:

```
cp main.v1 main
```

Finally, run the `main` program and wait a bit for it to update.

```sh
./main
# Running program version: 1, binary file version: 1
# Running program version: 1, binary file version: 1
# ...
# Running program version: 1, binary file version: 1
# Executable file has been updated to version 3.
# Running program version: 1, binary file version: 3
# Running program version: 1, binary file version: 3
# ...
^C
```

The next time the program runs, it will display version 3 instead of version 1
for both software and executable and the checksum of `main` and `main.v3` will
be the same.

```sh
./main
# Running program version: 3, binary file version: 3
# Running program version: 3, binary file version: 3
# Running program version: 3, binary file version: 3
# ...
^C
```

[1]: https://equinox.io/
