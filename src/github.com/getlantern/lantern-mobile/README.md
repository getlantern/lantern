# Lantern Android

## Overview

<img src="screenshots/screenshot1.png" height="330px" width="200px">

Lantern Android is an App that uses the Android [VpnService][4] API to route
all device traffic through a packet interception service and subsequently the
Lantern circumvention tool.

## Building Lantern Android

Before building make sure you've compiled the Lantern proxy for Android:

```
cd $GOPATH/src/github.com/getlantern/lantern
make android-lib
```

### Building from Android Studio

#### Prerequisites

* [Android Studio][1]
* Git
* [Android NDK][2]

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
* [Android NDK][2]
* [Android SDK Tools][4] (if not using Android Studio)
* Go (1.6 tip is best as it eliminates text-relocations and provides the best performance)

Replace the paths based on wherever you've installed the Android SDK and NDK

```bash
export ANDROID_HOME=/opt/adt-bundle-mac-x86_64-20130917/sdk
export PATH=$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/23.0.2/:$PATH
export NDK_HOME=/opt/android-ndk-r10e
export PATH=$NDK_HOME:$PATH
```

Using the sdk-manager (`$ANDROID_HOME/tools/android`), install Android 6.0 API
23 and also the Android SDK Build Tools rev. 23.0.1.

#### Building `tun2socks`

Lantern Android uses [tun2socks][3] to route intercepted VPN traffic through a
local SOCKS server.

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

Note - if you want to test with an emulator, run `android` and then choose
Tools -> Manage AVDs.  Create an AVD (e.g. Nexus_4) and then run the emulator
from the command line like so:

```
emulator -avd Nexus_4
```

The following settings seem to work well enough performance wise:

```
Device: 3.4" WQVGA 240x432
Target: Android 5.1.1 - API Level 22
CPU/ABI: ARM (armeabi-v7a)
Keyboard: x Hardware keyboard present
Skin: Skin with dynamic hardware controls
Front Camera: None
Back Camera: None
Memory RAM: 2048
VM Heap: 128
Internal Storage: 200
SD Card: 4GiB (probably more than necessary)
Emulation Options: x Use Host GPU
```

#### Testing the app

#### Debugging

With Lantern Android running, to filter Logcat messages:

```
make logcat
```

#### Simulating tun2socks and lantern outside Android

This is very useful when you can to check each moving part separately.

Within Android, the [VpnService][4] creates a [TUN device][5] and configures
the network to route all traffic to this virtual device, an app is listening on
this device and has the ability to inspect, modify and reinject packets back to
the device. Some special packets can ignore the tun device and pass to the
Internet directly ([protected packages][6]).

We are going to use a Linux virtual machine to simulate the `device <-> tun <->
tun2sock <-> lantern <-> Internet` dance, on a normal Linux we don't have the
[VpnService][4] API but we have the ability to create tun devices and route
traffic at will.

The main idea is to create a tun device, run a vanilla tun2socks and route all
outgoing traffic to this device, everything but DNS server requests and a
special route that goes directly to the virtual machine's host, which will be
running a Lantern-SOCKs server.

Let's create and configure this virtual machine:

```
cd /path/to/lantern-mobile
vagrant up
```

While you're waiting for the vm to build up go back to the local machine (the
vm's host) and compile the socks-server:

```
cd ~/go/src/github.com/getlantern/lantern
source setenv.bash
go build github.com/getlantern/lantern-mobile/lantern/socks-server
```

Run the server you've just compiled:

```
./socks-server
# ...
# DEBUG lantern-android.interceptor: interceptor.go:90 SOCKS proxy now listening on port: 8788
# 2015/09/15 08:47:40 Go and play for 10 minutes.
```

Run a simple test with cURL and watch the `sock-server` output.

```
curl --socks5 127.0.0.1:8788 https://www.google.com/humans.txt
# Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.
```

The SOCKs server will run for 10 minutes and then it will exit, you can also
stop it anytime with `^C`.

You can also cross-compile the tests we're going to run within the vm:

```
cd ~/go/src/github.com/getlantern/lantern
make mobile-test-linux-amd64
# ...
# ok      github.com/getlantern/lantern-mobile/lantern    0.082s
```

Once the build has finished log in into the new box:

```
vagrant ssh
```

And run the script that is going to setup

```
chmod +x /vagrant/vagrant-tun-up.sh
/vagrant/vagrant-tun-up.sh
```

The script will ask you for a `HOST_IP`, this is the IP of the host machine
which in my case is `10.0.0.101`:

```
HOST_IP=10.0.0.101 /vagrant/vagrant-tun-up.sh
# NOTICE(tun2socks): initializing BadVPN tun2socks 1.999.130
# NOTICE(tun2socks): entering event loop
```

Go back to your host and restart the socks-server.

```
./socks-server
# ^C
./socks-server
# ...
```

Open another terminal without stopping the tun2socks process and we'll be ready
to test everything.

```
vagrant ssh
curl https://www.google.com/humans.txt
# Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.
```

Make sure the request is catched by tun2socks and by the socks-server by
watching each program's output.

Finally, run the transparent test, which will basically do the same as a normal
cURL through tun2socks and the socks-server:

```
/vagrant/lantern/lantern_mobile_test -test.v -test.run TestTransparentRequestPassingThroughTun0
# ...
# --- PASS: TestTransparentRequestPassingThroughTun0 (1.36s)
# PASS
```

[1]: http://developer.android.com/tools/studio/index.html
[2]: https://developer.android.com/ndk/downloads/index.html#download
[3]: https://code.google.com/p/badvpn/wiki/tun2socks
[4]: http://developer.android.com/reference/android/net/VpnService.html
[5]: https://www.kernel.org/doc/Documentation/networking/tuntap.txt
[6]: http://developer.android.com/reference/android/net/VpnService.html#protect(int)
[7]: http://developer.android.com/sdk/index.html#Other
