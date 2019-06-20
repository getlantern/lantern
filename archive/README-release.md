## Building Lantern for Releases

For release builds, you'll want to use Docker:

* [Docker](https://www.docker.com/).

We are going to create a Docker image that will take care of compiling Lantern
for Windows and Linux, in order to compile Lantern for OSX you'll need an OSX
host, this is a limitation caused by Lantern depending on C code and OSX build
tools for certain features.

*Any target can be run on Docker by prefixing it with 'docker-'*, e.g.
`make windows` runs locally and `make docker-windows` runs in docker.

### Docker Installation Instructions

1. Get the [Docker Toolbox](https://www.docker.com/docker-toolbox)
2. Install docker per [these instructions](https://docs.docker.com/mac/step_one/)

After installation, you'll have a docker machine called `default`, which is what the build script uses. You'll probably want to increase the memory and cpu for the default machine, which will require you to recreate it:

```bash
docker-machine rm default
docker-machine create --driver virtualbox --virtualbox-cpu-count 2 --virtualbox-memory 4096 default
```

### Migrating from boot2docker

If you already have a boot2docker vm that you want to use with the new
docker-toolbox, you can migrate it with this command:

```bash
docker-machine create -d virtualbox --virtualbox-import-boot2docker-vm boot2docker-vm default
```

### Building the docker image

In order to build the docker image open a terminal, `cd` into the
`lantern` project and execute `make docker`:

```sh
cd lantern
make docker
```

This will take a while, be patient, you only need to do this once.

## Building Lantern binaries

### Building for Linux

If you want to build for Linux on all supported architectures, use:

```sh
make linux
```

You can also build for Linux 386:

```sh
make linux-386
file lantern_linux_386
# lantern_linux_386: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked (uses shared libs), not stripped
```

Or only for amd64:

```sh
make linux-amd64
file lantern_linux_amd64
# lantern_linux_amd64: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked (uses shared libs), not stripped
```

Or ARM:

```sh
make linux-arm
file lantern_linux_arm
# lantern_linux_arm: ELF 32-bit LSB executable, ARM, version 1 (SYSV), dynamically linked (uses shared libs), not stripped
```


### Building for Windows

Lantern supports the 386 architecture on Windows. In order to build Lantern on
Windows use:

```sh
make windows
file lantern_windows_386.exe
# lantern_windows_386.exe: PE32 executable for MS Windows (GUI) Intel 80386 32-bit
```

### Building for OSX

Lantern supports the amd64 architecture on OSX. In order to build Lantern on
OSX you'll need an OSX host. Run the following command:

```sh
make darwin
file lantern_darwin_amd64
# lantern_darwin_amd64: Mach-O 64-bit executable x86_64
```

### Building all binaries

If you want to build all supported binaries of Lantern use the `binaries` task:

```sh
make binaries
```

### Building headless version

If `HEADLESS` environment variable is set, the generated binaries will be
headless, that is, it doesn't depend on the systray support libraries, and
will not show systray or UI.

## Packaging

Packaging requires some special environment variables.

### OSX

Lantern on OS X is packaged as the `Lantern.app` app bundle, distributed inside
of a drag-and-drop dmg installer. The app bundle and dmg can be created using:

```sh
VERSION=2.0.0-beta2 make package-darwin
file Lantern.dmg
# Lantern.dmg: bzip2 compressed data, block size = 100k
```

`make package-darwin` signs the Lantern.app using the BNS code signing
certificate in your KeyChain. The
[certificate](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12)
and
[password](https://github.com/getlantern/too-many-secrets/blob/master/osx-code-signing-certificate.p12.txt)
can be obtained from
[too-many-secrets](https://github.com/getlantern/too-many-secrets) and must be
installed to the system's key chain beforehand.

If signing fails, the script will still build the app bundle and dmg, but the
app bundle won't be signed. Unsigned app bundles can be used for testing but
should never be distributed to end users.

The background image for the DMG is
`installer-resources/darwin/dmgbackground.svg`.

### Packaging for Windows

Lantern on Windows is distributed as an installer built with
[nsis](http://nsis.sourceforge.net/). The installer is built and signed with
`make docker-package-windows`.

For `make package-windows` to be able to sign the executable, the environment variables
`SECRETS_DIR` and `BNS_CERT_PASS` must be set to point to the secrets directory
and the
[password](https://github.com/getlantern/too-many-secrets/blob/master/build-installers/env-vars.txt#L3)
of the BNS certificate.  You can set the environment variables and run the
script on one line, like this:

```sh
SECRETS_DIR=$PATH_TO_TOO_MANY_SECRETS BNS_CERT_PASS='***' \
VERSION=2.0.0-beta1 make package-windows
```

### Packaging for Ubuntu

Lantern on Ubuntu is distributed as a `.deb` package. You can generate a Debian
package with:

```sh
VERSION=2.0.0-beta2 make docker-package-linux
```

The version string must match the Debian requirements:

https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version

This will build both 386 and amd64 packages.

### Generating all packages

Use the `make packages` task combining all the arguments that
`package-linux`, `package-windows` and `package-darwin` require.

```sh
SECRETS_DIR=$PATH_TO_TOO_MANY_SECRETS BNS_CERT_PASS='***' \
VERSION=2.0.0-beta1 make packages
```

## Creating releases

### Releasing for QA

In order to release for QA, first obtain an [application token][1] from Github
(`GH_TOKEN`) and then make sure that [s3cmd](https://github.com/s3tools/s3cmd)
is correctly configured:

```
s3cmd --config
```

Then, create all distribution packages:

```
[...env variables...] make packages
```

Finally, use `release-qa` to upload the packages that were just generated to
both AWS S3 and the Github release page:

```
VERSION=2.0.0-beta5 make release-qa
```

### Releasing Beta

If you want to release a beta you must have created a package for QA first,
then use the `release-beta` task:

```
make release-beta
```

`release-beta` will promote the QA files that are currently in S3 to beta.

### Releasing for production

After you're satisfied with a beta version, it will be time to promote beta
packages to production and to publish the packages for auto-updates:

```
VERSION=2.0.0-beta5 GH_TOKEN=$GITHUB_TOKEN make release
```

`make release` expects a `lantern-binaries` directory at `../lantern-binaries`.
You can provide a different directory by passing the `LANTERN_BINARIES_PATH`
env variable.
