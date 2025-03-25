# Lantern
[![en](https://github.com/getlantern/.github/blob/main/resources/English.svg)](https://github.com/getlantern/.github/blob/main/profile/README.md)
[![zh](https://github.com/getlantern/.github/blob/main/resources/Chinese.svg)](https://github.com/getlantern/.github/blob/main/profile/README.zh.md)
[![ru](https://github.com/getlantern/.github/blob/main/resources/Russian.svg)](https://github.com/getlantern/.github/blob/main/profile/README.ru.md)
[![ar](https://github.com/getlantern/.github/blob/main/resources/Arabic.svg)](https://github.com/getlantern/.github/blob/main/profile/README.ar.md)
[![fa](https://github.com/getlantern/.github/blob/main/resources/Farsi.svg)](https://github.com/getlantern/.github/blob/main/profile/README.fa.md)
[![my](https://github.com/getlantern/.github/blob/main/resources/Burmese.svg)](https://github.com/getlantern/.github/blob/main/profile/README.my.md)
---
Censorship circumvention tool available for free download on any operating system

![cover page](https://github.com/getlantern/.github/blob/main/resources/cover_page.png)

# Build and run the app on macOS (debug mode)
```
make macos
flutter build macos --debug
sudo build/macos/Build/Products/Debug/Lantern.app/Contents/MacOS/Lantern
```

# Build and run the app on iOS

```
make ios
flutter devices
flutter run -d deviceID
```

# Build and run the Android app

1. Install Go and gomobile

```
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

2. Install Android SDK and NDK

```
sdkmanager "ndk;23.1.7779620" "cmake;3.18.1" "platform-tools"
```

3. Build the Android app

```
make android-debug
```

After running `make android-debug`, you’ll find the APK here:

```
build/app/outputs/flutter-apk/app-debug.apk
```

# Running the Full Setup on macOS with an iOS Device

If you’re using macOS and have your iOS device connected to the same local network, you can test the full setup end-to-end by updating the primary proxy address in [config/local.json](config/local.json#L2) to your Mac’s local network IP.

1. Run a Local Shadowsocks Server on macOS

```
brew install shadowsocks-libev
```

Start the Shadowsocks server:

```
ssserver -s 0.0.0.0:8388 -m aes-256-gcm -k "mytestpassword" -vvvv
```

If install via homebrew, you can run the following command:

```
ss-server -s 0.0.0.0 -p 8388 -m aes-256-gcm -k "mytestpassword" -vvvv
```


2. Update the Proxy Address in the Config

Locate your Mac’s local IP address:

```
ipconfig getifaddr en0
```

Edit [config/local.json](config/local.json#L2) and update the primary proxy address ("addr") with your local IP (e.g., "192.168.1.100").

3. Build and Run the iOS App

Now, when you run the iOS app, it should be able to connect to the local Shadowsocks proxy and test the full setup.
