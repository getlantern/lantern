# lantern [![Travis CI Status](https://travis-ci.org/getlantern/lantern.svg?branch=valencia)](https://travis-ci.org/getlantern/lantern)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/lantern/badge.png?branch=valencia)](https://coveralls.io/r/getlantern/lantern)&nbsp;[![ProjectTalk](http://www.projecttalk.io/images/gh_badge-3e578a9f437f841de7446bab9a49d103.svg?vsn=d)] (http://www.projecttalk.io/boards/getlantern%2Flantern?utm_campaign=gh-badge&utm_medium=badge&utm_source=github)

**If you're looking for Lantern installers, you can find all of them at the following links:**
- [Android](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta.apk)
- [Windows XP SP 3 and above](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta.exe)
- [OSX 10.8 and above](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta.dmg)
- [Ubuntu 14.04 32 bit](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta-32-bit.deb)
- [Ubuntu 14.04 64 bit](https://raw.githubusercontent.com/getlantern/lantern-binaries/master/lantern-installer-beta-64-bit.deb)
- [Arch Linux](https://aur.archlinux.org/packages/lantern)

**If you're looking for help, please visit below user forums:**

| [English](https://groups.google.com/forum/#!forum/lantern-users-en) | [中文](https://groups.google.com/forum/#!forum/lantern-users-zh) | [فارسی](https://groups.google.com/forum/#!forum/lantern-users-fa) | [français](https://groups.google.com/forum/#!forum/lantern-users-fr)

## Building Lantern

### Prerequisites

* [Git](https://git-scm.com/downloads) - `brew install git`, `apt-get install git`, etc
* [Go 1.6 or higher](https://golang.org/dl/).
* [GNU Make](https://www.gnu.org/software/make/)
* [Nodejs & NPM](https://nodejs.org/en/download/package-manager/)
* GNU C Library (linux only) - `apt-get install libc6-dev-i386`, etc
* [Gulp](http://gulpjs.com/) - `npm i gulp -g`

To build and run Lantern desktop, just do:

```sh
git clone https://github.com/getlantern/lantern.git
cd lantern
make lantern
./lantern
```

During development, you'll likely want to do a clean build like this:

```sh
make clean-desktop lantern && ./lantern
```

## Building Mobile

### Mobile Prerequisites

Building the mobile library and app requires the following:

1. Install Java JDK 7 or 8
2. Install Go 1.6 or higher
3. Install [Android SDK Tools](http://developer.android.com/sdk/index.html#Other)
4. Install NDK(http://developer.android.com/ndk/downloads/index.html)

Make sure to set these environment variables before trying to build any Android
components (replace the paths based on wherever you've installed the Android
SDK and NDK).

```bash
export ANDROID_HOME=/opt/adt-bundle-mac-x86_64-20130917/sdk
export PATH=$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools:$PATH
export NDK_HOME=/opt/android-ndk-r10e
export PATH=$NDK_HOME:$PATH
```

### Go Android Library

The core Lantern functionality can be packaged into a native Android library
with:

```
make android-lib
```

### Java Android SDK

The Java-based Android SDK allows easy embedding of Lantern functionality in 3rd
party Android apps such as Manoto TV. The SDK can be built with:

```
make android-sdk
```

### Lantern Mobile Testbed

This simple Android application provides a way to test the Android SDK. It can
be built with:

```
make android-testbed
```

### Lantern Mobile App


## Debug

To create a debug build of the full lantern mobile app:

```
make android-debug
```

To install on the default device:

```
make android-install
```

## Release

To create a release build, add the following to your
``~/.gradle/gradle.properties`` file:

```
KEYSTORE_PWD=$KEYSTORE_PASSWORD
KEYSTORE_FILE=keystore.release.jks
KEY_PWD=$KEY_PASSWORD
```

You can find the exact values to add to your gradle.properties
[here](https://github.com/getlantern/too-many-secrets/blob/master/android/keystore).

Then it can be built with:

```sh
SECRETS_DIR=$PATH_TO_TOO_MANY_SECRETS \
VERSION=2.0.0-beta1 make android-release
```

### Android Tips
#### Uninstall for All Users
If you use `adb` to install and debug an app to your Android device during
development and then subsequently build a signed APK and try to install it on
that same device, you may receive an unhelpful error saying "App Not Installed".
This typically means that you tried to install the same app but signed with a
different key.  The solution is to uninstall the app first, but **you have to
uninstall it for all users**. You can do this by selecting "Uninstall for all
users" from:

```
Settings -> Apps -> [Pick the App] -> Hamburger Menu (...) -> Uninstall for all users.
```

If you forget to do this and just uninstall normally, you'll still encounter the
error. To fix this, you'll have to run the app with `adb` again and then
uninstall for all users.

#### Getting HTTP Connections to Use Proxy

In android, programmatic access to HTTP resources typically uses the
`HttpURLConnection` class.  You can tell it to use a proxy by setting some
system properties:

```java
System.setProperty("http.proxyHost", host);
System.setProperty("http.proxyPort", port);
System.setProperty("https.proxyHost", host);
System.setProperty("https.proxyPort", port);
```

You can disable proxying by clearing those properties:

```java
System.clearProperty("http.proxyHost");
System.clearProperty("http.proxyPort");
System.clearProperty("https.proxyHost");
System.clearProperty("https.proxyPort");
```

However, there is one big caveat - **`HttpURLConnection` uses keep-alives to
reuse existing TCP connections**. These TCP connections will still be using the
old proxy settings. This has several implications:

**Set the proxy settings as early in the application's lifecycle as possible**,
ideally before any `HttpURLConnection`s have been opened.

**Don't expect the settings to take effect immediately** if some
`HttpURLConnection`s have already been opened.

**Disable keep-alives if you need to**, which you can do like this:

```java
HttpURLConnection urlConnection = (HttpURLConnection) url.openConnection();
// Need to force closing so that old connections (with old proxy settings) don't get reused.
urlConnection.setRequestProperty("Connection", "close");
```

## Building Lantern for running on a server
To run Lantern on a server, you simply need to set a flag to build it in headless mode and then tell it to run on any local address as opposed to binding to localhost (so that it's accessible from other machines). You can do this as follows:

1. ```HEADLESS=true make docker-linux``` or, if you're already running on Linux just ```HEADLESS=true make linux```
1. ```./lantern_linux_amd64 --addr 0.0.0.0:8787``` or ```./lantern_linux_386 --addr 0.0.0.0:8787```

## Other
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

If you want to both create a package and upload a tag, run the `create-tag` task
right after the `packages` task:

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
per the instructions [here](https://docs.travis-ci.com/user/encrypting-files/).


## Documentation for developers

### Dev README

Please, go to [README-dev](README-dev.md) for an in-depth explanation of the Lantern internals and cloud services.

### Release README

Please visit [README-release](README-release.md) for details on building release versions of Lantern.

### Translations README

More info for dealing with translations is available in [README-translations](README-translations.md).

### Contributing changes
Lantern is a [gost](https://github.com/getlantern/gost) project that
provides repeatable builds and consolidated pull requests for lantern.

Go code in Lantern must pass several tests:

* [errcheck](https://github.com/kisielk/errcheck)
* [golint](https://github.com/golang/lint)
* Go vet
* Go test -race

You can find a generic [git-hook](https://github.com/getlantern/lantern/blob/valencia/pre-push)
file, which can be used as a pre-push (or pre-commit) hook to automatically
ensure these tests are passed before committing any code. Only Go packages in
`src/github.com/getlantern` will be tested, and only those that have changes in
them.

Install by copying it into the local `.git/hooks/` directory, with the `pre-push`
file name if you want to run it before pushing. Alternatively, you can copy
[pre-commit.hook](https://github.com/getlantern/lantern/blob/valencia/pre-commit)
to `pre-commit` to run it before each commit.

```bash
ln -s "$(pwd)/prehook.sh" .git/hooks/prehook.sh
ln -s "$(pwd)/pre-push" .git/hooks/pre-push
```

**Important notice**

If you *must* commit without running the hooks, you can run git with the
`--no-verify` flag.



[1]: https://help.github.com/articles/creating-an-access-token-for-command-line-use/
