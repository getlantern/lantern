# lantern [![Travis CI Status](https://travis-ci.org/getlantern/lantern.svg?branch=valencia)](https://travis-ci.org/getlantern/lantern)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/lantern/badge.png?branch=valencia)](https://coveralls.io/r/getlantern/lantern)

**If you're looking for Lantern binaries, you can find all of them at the following links:**
- [Windows XP SP 3 and above](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta.exe)
- [OSX 10.8 and above](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-manoto.dmg)
- [Ubuntu 14.04 32 bit](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-manoto-32-bit.deb)
- [Ubuntu 14.04 64 bit](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-manoto-64-bit.deb)



lantern is a [gost](https://github.com/getlantern/gost) project that
provides repeatable builds and consolidated pull requests for lantern.

## Building Lantern

### Requisites

* [Go 1.4.x](https://golang.org/dl/).
* [Docker](https://www.docker.com/).
* [GNU Make](https://www.gnu.org/software/make/)
* An OSX or Linux host.

We are going to create a Docker image that will take care of compiling Lantern
for Windows and Linux, in order to compile Lantern for OSX you'll need an OSX
host, this is a limitation caused by Lantern depending on C code and OSX build
tools for certain features.


### Contributing changes

Go code in Lantern must pass several tests:

* [errcheck](https://github.com/kisielk/errcheck)
* [golint](https://github.com/golang/lint)
* Go vet
* Go test -race

You can find a generic [git-hook](https://github.com/getlantern/lantern/blob/valencia/git-hook)
file, which can be used as a pre-push (or pre-commit) hook to automatically
ensure these tests are passed before committing any code. Only Go packages in
`src/github.com/getlantern` will be tested, and only those that have changes in
them.

Install by copying it into the local `.git/hooks/` directory, with the `pre-push`
file name if you want to run it before pushing. Alternatively, you can name it
`pre-commit` to run it before each commit..

**Important notice**

If you *must* commit without running the hooks, you can run git with the
`--no-verify` flag.


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
`make package-windows`.

For `make package-windows` to be able to sign the executable, the environment varaibles
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
VERSION=2.0.0-beta2 make package-linux
```

The version string must match the Debian requirements:

https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version

This will build both 386 and amd64 packages.

### Generating all packages

Use the `make packages` task combining all the arguments that `package-linux`,
`package-windows` and `package-darwin` require.

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

## Other tasks

### Creating the Android embeddable library

In order to build the Android ARM library that can be embedded in applications,
Lantern is using `gomobile`. This simplifies the process notably.

Currently, as Go 1.5 is not stable, a specific git revision is used within an
isolated Docker image.

To build a development library (takes shorter time):

```
make android-lib
```

To build the final version for Firetweet

```
make android-lib-dist
```

If you pass the `FIRETWEET_MAIN_DIR` env variable to `make android-lib`, the
generated bindings and library will be copied into it:

```
FIRETWEET_MAIN_DIR=/path/to/firetweet/src/main make android-lib
```

You can also override this environment variable if you want to use the
[Flashlight Android Tester](https://github.com/getlantern/flashlight-android-tester) app.


### Generating assets

```sh
make genassets
```

If the environment variable `UPDATE_DIST=true` is set, `make genassets` also
updates the resources in the dist folder.

An annotated tag can be added like this:

```sh
git tag -a v1.0.0 -m"Tagged 1.0.0"
git push --tags
```

Use `make create-tag` as a shortcut for creating and uploading tags:

```
VERSION='2.0.0-beta5' make create-tag
```

If you want to both create a package and upload a tag run the `create-tag` task
right after the `packages` task.

```
[...env variables...] make packages create-tag
```

### Updating Icons

The icons used for the system tray are stored in
`src/github/getlantern/lantern/icons`. To apply changes to the icons, make
your updates in the icons folder and then run `make update-icons`.

### Continuous Integration with Travis CI

Continuous builds are run on Travis CI. These builds use the `.travis.yml`
configuration.  The github.com/getlantern/cf unit tests require an envvars.bash
to be populated with credentials for cloudflare. The original `envvars.bash` is
available
[here](https://github.com/getlantern/too-many-secrets/blob/master/envvars.bash).
An encrypted version is checked in as `envvars.bash.enc`, which was encrypted
per the instructions [here](http://docs.travis-ci.com/user/encrypting-files/).

[1]: https://help.github.com/articles/creating-an-access-token-for-command-line-use/
