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

Download the equinox tool from the dashboard.

We are going to sign our releases, that's why we need a keypair. Create a new
one using `openssl`:

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

Create a `equinox.yaml` file, we're going to store settings for `equinox`.

```yaml
---
account_id: id_XXX
secret_key: key_YYY
application_id: ap_ZZZ
channel: stable
private-key: ./private.pem
```

Use the `equinox` tool to update a new version, instead of using floating point
numbers to describe a release, use integers, it will be easier as the next
greatest number than `n` is always defined by `n + 1` and we'll have no chance
of hitting a bug derived from comparison of floating point values.

```sh
equinox release --config equinox.yaml --version=1 main.go
# ...
```

Note: I've found my `equinox` tool does not actually cares about the
`equinox.yaml` file. So I feed these values directly:

```sh
equinox release --config equinox.yaml --version=1 main.go
# EROR[02-08|07:37:36] missing required argument                fn=parseOpts arg=equinox-account
# CRIT[02-08|07:37:36] failed to parse options                  err="equinox-account argument is required"
equinox release --equinox-secret key_YYY --equinox-account id_XXX --channel 'stable' --equinox-app ap_ZZZ --private-key ./private.pem --version=1 main.go
# Success!
```

In order to actually test auto updates, you need to increase the
`internalVersion` within `main.go` and use equinox to build and update the
binary.

Increate `internalVersion` to 2 and upload it:

```sh
equinox release ... --version=2 main.go
```

Then, bump it to `3` and upload it again:

```sh
equinox release ... --version=3 main.go
```

Now reset the file and build `main.go`:

```sh
git checkout main.go
go build main.go
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
for both software and executable.

```sh
./main
# Running program version: 3, binary file version: 3
# Running program version: 3, binary file version: 3
# Running program version: 3, binary file version: 3
# ...
^C
```

[1]: https://equinox.io/
