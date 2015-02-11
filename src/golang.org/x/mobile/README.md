# Go support for Mobile devices

The Go mobile repository holds packages and build tools for using Go on Android.

This is early work and the build system is a bumpy ride. Building a binary for
Android requires using a Go cross compiler and an external linker from the NDK.

For now, the easiest way to setup a build environment is using the provided
Dockerfile:

	docker pull golang/mobile

Get the sample applications.

	go get -d golang.org/x/mobile/example/...

In your app directory under your `$GOPATH`, copy the following files from either
the [golang.org/x/mobile/example/basic](https://github.com/golang/mobile/tree/master/example/basic)
or [golang.org/x/mobile/example/libhello](https://github.com/golang/mobile/tree/master/example/libhello)
apps:

	AndroidManifest.xml
	all.bash
	build.xml
	jni/Android.mk
	make.bash

Start with `basic` if you are writing an all-Go application (that is, an OpenGL game)
or libhello if you are building a `.so` file for use from Java via
[gobind](https://godoc.org/golang.org/x/mobile/cmd/gobind). Edit the files to change
the name of your app.

To build, run:

	docker run -v $GOPATH/src:/src golang/mobile /bin/bash -c 'cd /src/your/project && ./make.bash'

Note the use of -v option to mount $GOPATH/src to /src of the container.
The above command will fail if the -v option is missing or the specified
volume is not accessible from the container.

When working with an all-Go application, this will produce a binary at
`$GOPATH/src/your/project/bin/name-debug.apk`. You can use the adb tool to install
and run this app. See all.bash for an example.

--

APIs are currently very limited, but under active development. Package
documentation serves as a starting point:

- [mobile/app](http://godoc.org/golang.org/x/mobile/app)
- [mobile/gl](http://godoc.org/golang.org/x/mobile/gl)
- [mobile/sprite](http://godoc.org/golang.org/x/mobile/sprite)
- [mobile/cmd/gobind](http://godoc.org/golang.org/x/mobile/cmd/gobind)

Contributions to Go are appreciated. See https://golang.org/doc/contribute.html.
