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

# Overview of iOS VPN implementation

The iOS app utilizes NEPacketTunnelProvider in Swift to manage the VPN tunnel and handle network packet capture.

It integrates with a Go-based lwIP stack through FFI, allowing seamless communication between the two languages.

The VPN application is divided into four components:

- [Go backend](vpn): Handles the core networking logic using go-tun2socks’s LWIPStack, a lightweight IP stack for handling network packets and managing TCP/UDP connections
- [Swift Bridge](ios/Runner): Intermediary between the Go backend and iOS.
- [Packet Tunnel Provider](ios/Tunnel) (iOS): Manages the VPN session and interfaces with the iOS networking stack.
- [Dart/Flutter Frontend](lib): Provides the user interface, allowing users to control the VPN via a simple UI.

The Go backend makes use of StreamDialer & PacketListener from the Outline SDK to manage TCP streams and UDP packets, which facilitates communication between the client and a proxy server.

# Build and run the app on macOS
```
make macos
flutter run -d macOS
```

# Build and run the app on iOS

```
make build-framework
cd ios && pod install
flutter devices
flutter run -d deviceID
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
