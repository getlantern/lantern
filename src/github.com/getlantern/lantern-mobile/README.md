Lantern Android
================================================================================

Overview
--------------------------------------------------------------------------------

<img src="screenshots/screenshot1.png" height="330px" width="200px">

Lantern Android is an app that uses the Android VpnService API to route all device traffic through a packet interception service and subsequently the Lantern circumvention tool.

## Building Lantern Android

### Building from Android Studio

#### Prerequisites

* [Android Studio][1]
* Git

Download the most recent copy of the Lantern Android source code using `git`:

```
mkdir -p ~/AndroidstudioProjects
cd ~/AndroidstudioProjects
git clone https://github.com/getlantern/lantern-mobile.git
```

In the welcome screen choose the "Open an existing Android Studio" option and
select the `lantern` folder you just checked out with git.

### Building from the Command Line (beta, for development only)

#### Prerequisites

* Java Development Kit 1.7
* Git
* [Android NDK](https://developer.android.com/ndk/downloads/index.html#download)

#### Building Tun2Socks
Lantern Android uses [tun2socks](https://code.google.com/p/badvpn/wiki/tun2socks) to route intercepted VPN traffic through a local SOCKS server.

```
make build-tun2socks
```

#### Building, installing and running

Build the Debug target:

```
make build-debug
```

Install it:

```
make install
```

Run the app on the device from the command line:

```
make run
```

By default, all three tasks will be run in order with:

```
make
```

#### Debugging

With Lantern Android running, to filter Logcat messages:

```
make logcat
```

[1]: http://developer.android.com/tools/studio/index.html
