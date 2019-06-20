# _test_app

This is an example application that prints both the version of the running
program and the version of the executable file's. The purpose of this example
is to demonstrate how to use `github.com/getlantern/autoupdate` and the
`github.com/getlantern/autoupdate-server` packages.

## Instructions for integrating autoupdate with an application

Add a new entry for the application inside `config.go` that resembles the
following map:

```go
// config.go

var configMap = map[string]*config{
  // ...
  // "_test_app" will be used as the internal name of the application.
	"_test_app": &config{
		publicKey:     []byte("-----BEGIN PUBLIC KEY-----\nABCDEF\n-----END PUBLIC KEY-----\n"),
	},
  // ...
}
```

## How to test the autoupdate package?

Use the `generate.sh` script to build binaries for different operating systems
and architectures.

```sh
./generate.sh
```

This script will create binaries for Windows, Linux and OSX that match with
versions v0.1, v0.2, v0.3 and v0.4.

Create an entry in the github releases page for each one of the generated
versions, see https://github.com/getlantern/autoupdate-server/releases.

Note that the generated binaries follow this pattern:

```
autoupdate-binary-{windows|linux|darwin}-{amd64|386|arm}
```

The pattern above is required for the autoupdate-server to know which file
corresponds to which version, operating system and architecture.

The extension is optional and is ignored by the autoupdate-server.

Other files in the release that do not match the file pattern will also be
ignored.

Copy the v0.1 release of the os/architecture combination you're currently
working into a file named `main`:

```
$ cp autoupdate-binary-darwin-amd64.v1 main
```

Run the `main` file you've just created, it will eventually update itself to
the latest released version:

```
$ ./main
Running program version: v0.1.0, binary file version: v0.1.0
2015/03/13 16:47:16 autoupdate: Attempting to update to v0.4.
Running program version: v0.1.0, binary file version: v0.1.0
Running program version: v0.1.0, binary file version: v0.1.0
Running program version: v0.1.0, binary file version: v0.1.0
2015/03/13 16:47:20 autoupdate: Patching succeeded!
Executable file has been updated to version v0.4.
Running program version: v0.1.0, binary file version: v0.4
Running program version: v0.1.0, binary file version: v0.4
```

If you try to run the program again, it will be already up to date.

```
$ ./main
Running program version: v0.4.0, binary file version: v0.4.0
2015/03/13 16:47:28 autoupdate: Already up to date.
Running program version: v0.4.0, binary file version: v0.4.0
Running program version: v0.4.0, binary file version: v0.4.0
```

## About signatures

You may sign the executable with `codesign` or `osslsigncode` before uploading
the binary to github.
