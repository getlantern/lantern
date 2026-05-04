# Lantern — Developer Guide

Censorship circumvention tool available for free download on any operating system

![cover page](https://github.com/getlantern/.github/blob/main/resources/cover_page.png)


---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Getting Started](#3-getting-started)
4. [Lantern Core](#4-lantern-core)
5. [Building & Running](#5-building--running)
   - [macOS](#51-macos)
   - [iOS](#52-ios)
   - [Android](#53-android)
   - [Windows](#54-windows)
   - [Linux](#55-linux)
6. [Building Your Changes in CI](#6-building-your-changes-in-ci)
7. [Testing](#7-testing)
   - [Unit & Widget Tests](#71-unit--widget-tests)
   - [Integration Tests](#72-integration-tests)
   - [Linux VPN Smoke Test](#73-linux-vpn-smoke-test)
8. [Release & Publishing](#8-release--publishing)
   - [Tag format](#tag-format)
   - [How to release](#how-to-release)
   - [Nightly builds](#nightly-builds)
9. [Auto-Updater](#9-auto-updater)

---

## 1. Overview

Lantern is a censorship circumvention tool built with Flutter on the frontend and Go on the backend. The two layers communicate through a bridge that uses either FFI (macOS, Windows, Linux) or platform channels (iOS, Android).

**Core stack:**

| Layer | Technology |
|---|---|
| UI | Flutter + Dart |
| State management | Riverpod |
| Navigation | AutoRoute |
| Dependency injection | GetIt |
| Native bridge | Go via gomobile (FFI / platform channels) |
| Wire protocol | Protobuf |

---

## 2. Prerequisites

The following tools must be installed and available on your `PATH` before building any platform target.

| Tool | Required Version | Notes |
|---|---|---|
| Flutter | 3.41.0 (stable) | [flutter.dev](https://flutter.dev) or [fvm](https://fvm.app) |
| Go | 1.25.4 | [go.dev/dl](https://go.dev/dl) or [mise](https://mise.jdx.dev) |
| Git | any recent | system package manager |
| IDE | — | [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com) with the [Flutter extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) |
| Xcode | 26.x | Required only for iOS and macOS targets. Install from the Mac App Store. |
| gomobile | latest | Required for all platforms. Install via `make install-gomobile`. |

> The Flutter version is pinned in `pubspec.yaml` and the Go version is declared in `go.mod`. Using mismatched versions will cause build errors.

Verify your setup:

```bash
flutter doctor
go version
```

Platform-specific dependencies (Xcode, Android SDK, Visual Studio, etc.) are listed in each platform section below.

---

## 3. Getting Started

After cloning the repository, install Flutter package dependencies:

```bash
flutter pub get
```


> [!IMPORTANT]
> The app requires an `app.env` file at the repo root to configure API keys and environment-specific settings. Obtain `app.env` from **1Password** and place it at the root of the repository before building.

This resolves the Dart/Flutter packages declared in `pubspec.yaml` and writes dependency metadata to `.dart_tool/`. It must be run at least once before any build, and re-run whenever `pubspec.yaml` or `pubspec.lock` changes (e.g. after pulling commits that add or update packages).

---

## 4. Lantern Core

`lantern-core/` is the Go backend that powers all VPN and networking functionality. It is compiled into a native library and embedded into each platform target — as an `.xcframework` on Apple platforms, an `.aar` on Android, and a shared `.so`/`.dll` on desktop.

### How the bridge works

The Go backend is compiled into a platform-native library using `gomobile`. Dart communicates with it through one of two mechanisms depending on the platform:

- **FFI** (`dart:ffi`) — used on desktop platforms (macOS, Windows, Linux). Dart calls C-exported Go functions directly in-process. Lower overhead, synchronous call support.
- **Platform channels** (gomobile bindings) — used on mobile platforms (iOS, Android). Dart sends messages over a named channel; the native side invokes the Go library and returns the result asynchronously.

Both paths go through `LanternService` in Dart, which delegates to either `LanternFFIService` (desktop) or `LanternPlatformService` (mobile) based on the current platform.

| Platform | Bridge mechanism | Output artifact |
|---|---|---|
| macOS | FFI via `dart:ffi` | `Liblantern.xcframework` |
| iOS | Platform channels (gomobile) | `Lantern.xcframework` |
| Android | Platform channels (gomobile) | `liblantern.aar` |
| Windows | FFI via `dart:ffi` | `liblantern.dll` |
| Linux | FFI via `dart:ffi` | `liblantern.so` |

### Key packages inside `lantern-core/`

| Directory | Purpose |
|---|---|
| `core.go` | Entry point — initialises Radiance and wires up subsystems |
| `ffi/` | FFI entry points exposed to Dart on desktop platforms |
| `mobile/` | gomobile bindings for iOS and Android |
| `vpn_tunnel/` | Cross-platform VPN tunnel management |
| `private-server/` | Private server provisioning and management |
| `apps/` | Per-platform app-level helpers |
| `cmd/` | CLI entry points (service binaries) |
| `stub/` | Stub implementations used in tests |

### Updating the Go backend

After making changes inside `lantern-core/`, rebuild the native library for your target platform before running the Flutter app:

```bash
# macOS
make macos

# iOS
make ios

# Android
make android-debug

# Windows
make windows

# Linux
make linux
```

---

## 5. Building & Running

---

### 5.1 macOS

#### Prerequisites

- **Xcode 26.x** with macOS platform components installed
- After installing or updating Xcode, initialize the command-line tools once:

  ```bash
  sudo xcodebuild -runFirstLaunch
  ```

#### Provisioning profile

> [!IMPORTANT]
> A valid provisioning profile is required to build and sign the macOS app. Find the credentials in **1Password** under **BNS Apple Developer ID**, then download and import the profile to Xcode (by going to **Signing & Capabilities**).

#### Build and run

Build the native Go framework (outputs to `macos/Frameworks/`):

```bash
make macos
```

Run the Flutter desktop app:

```bash
flutter run -d macos
```

> **Xcode alternative:** Open `macos/Runner.xcworkspace` directly in Xcode to build and run without the CLI.

---

### 5.2 iOS

#### Prerequisites

- **Xcode 26.x** with the iOS Simulator or a physical iOS device

#### Provisioning profile

> [!IMPORTANT]
> A valid provisioning profile is required to build and run on a physical device. Find the credentials in **1Password** under **BNS Apple Developer ID**, then download and import the profile to Xcode (by going to **Signing & Capabilities**).

#### Build and run

Build the native iOS framework (outputs to `ios/Frameworks/`):

```bash
make ios
```

List available devices and simulators:

```bash
flutter devices
```

Run on a specific device using its ID:

```bash
flutter run -d <deviceID>
```

> **Xcode alternative:** Open `ios/Runner.xcworkspace` directly in Xcode to build and run without the CLI.

---

### 5.3 Android

#### Prerequisites

- **Java 17 or newer** — Required by Gradle. Install a JDK distribution such as [Eclipse Temurin](https://adoptium.net) and ensure `JAVA_HOME` points to it.

  ```bash
  java -version   # should print 17.x or higher
  ```

- **Android Studio** (or the standalone [Android command-line tools](https://developer.android.com/studio#command-line-tools-only)) — provides the `sdkmanager` utility used in the next step.

#### Install Android SDK components

```bash
make install-android-sdk
```

This installs the following components and accepts all SDK licenses automatically:

| Component | Version |
|---|---|
| Platform | android-35 (API 35) |
| Build tools | 35.0.0 |
| NDK | 27.0.12077973 |
| CMake | 3.22.1 |

After the NDK is installed, set the following environment variables so the build tools can locate it:

```bash
export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/27.0.12077973
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
export NDK_HOME=$ANDROID_NDK_HOME
```

> Rather than adding these to your global shell profile, manage them with a repo-local config file:
> - **[direnv](https://direnv.net)**: place the `export` lines in a `.envrc` file at the repo root, then run `direnv allow`. Add `.envrc` to `.git/info/exclude` to keep it untracked.
> - **[mise](https://mise.jdx.dev)**: add an `[env]` block to a `.mise.local.toml` file at the repo root (`*.local.toml` files are intended for personal overrides and are not committed).

#### Install build dependencies

Installs the necessary libraries and packages required for Android development:

```bash
make install-android-deps
```

#### Build and run

Build the native Go AAR library (outputs to `android/app/libs/`):

```bash
make android
```

List connected devices:

```bash
flutter devices
```

Run on a connected Android device or emulator:

```bash
flutter run -d <deviceID>
```

#### Debug build

To build a debug APK directly:

```bash
make android-debug
```

Output APK location:

```
build/app/outputs/flutter-apk/app-debug.apk
```

---

### 5.4 Windows

The Windows build separates the backend (a Windows Service binary) from the Flutter UI. During development you can run the backend in console mode instead of registering it as a real service, which makes for a faster iteration loop.

#### Prerequisites

- **Windows 10** or newer
- **Visual Studio 2022** with the **Desktop development with C++** workload (required by Flutter Windows)
- **PowerShell 5.1+** (included with Windows 10)
- **Go** and **Flutter** as listed in [Prerequisites](#2-prerequisites)

#### Quick dev loop

1. Build the Windows service binary (from an elevated PowerShell):

   ```powershell
   make windows-service-build
   ```

2. Start the backend in console mode:

   ```powershell
   .\bin\windows-amd64\lanternsvc.exe --console
   ```

3. Build the native shared library:

   ```bash
   make windows
   ```

4. Run the Flutter desktop app:

   ```bash
   flutter run -d windows
   ```

The Flutter app communicates with the service via a named pipe.

#### Running as a real Windows Service

To run the backend as a real Windows Service during development, use the [helper scripts](scripts/windows) from an elevated PowerShell:

| Script | Purpose |
|---|---|
| `service_install.ps1` | Install and start the service |
| `service_stop.ps1` | Stop the service |
| `service_remove.ps1` | Remove the service |

---

### 5.5 Linux

#### Prerequisites

- **Ubuntu 20.04+ or Debian 11+** (other systemd-based distros should work)
- **systemd** — the backend runs as a systemd daemon
- `apt` package manager for the install step
- **Go** and **Flutter** as listed in [Prerequisites](#2-prerequisites)

#### Install build dependencies

```bash
make install-linux-deps
```

#### Build

Build the Linux release artifacts (`.deb` package):

```bash
make linux-release
```

#### Install and run

1. Install the `.deb` package (requires root only for this step):

   ```bash
   sudo apt install ./lantern-installer-*.deb
   ```

2. Check the daemon is running:

   ```bash
   systemctl status lanternd.service
   ```

3. Run the Flutter app as your normal user:

   ```bash
   flutter run -d linux
   ```

#### Troubleshooting

View daemon logs:

```bash
journalctl -u lanternd.service -n 200 --no-pager
```

#### Uninstall

```bash
sudo systemctl disable --now lanternd.service
sudo apt remove lantern
sudo rm -f /usr/lib/systemd/system/lanternd.service /usr/lib/lantern/lanternd
sudo systemctl daemon-reload
```

---

## 6. Building Your Changes in CI

If you want to generate a build for your changes to test, you can trigger a nightly build manually from GitHub Actions against your branch.

1. Go to **Actions** → **Build and Release** in the GitHub repository
2. Click **Run workflow**
3. Select your branch from the branch dropdown
4. Set **Build type** to `nightly`
5. Set **Platforms** to the platform(s) you want to build (e.g. `android`, `ios`, or `all`)
6. Click **Run workflow**

> **Note:** Triggering from a non-default branch creates a draft release that is automatically deleted after the artifacts are uploaded. You can download the artifacts directly from the workflow run summary before they are cleaned up.

### Tweaking a release-build daemon at runtime

Release builds don't expose the dev-mode UI, but the radiance daemon still
listens on a local IPC socket (`/var/run/lantern/lanternd.sock` on macOS and
Linux). `scripts/radiance-env.sh` is a thin wrapper around that socket for
inspecting and patching the daemon's environment without rebuilding.

```bash
# show current env
./scripts/radiance-env.sh

# force a specific track (handy for testing a track that the bandit isn't
# yet selecting for your UID)
./scripts/radiance-env.sh force-track unbounded-linode-free
./scripts/radiance-env.sh poll          # trigger an immediate config-fetch

# clear the override
./scripts/radiance-env.sh force-track ""

# arbitrary KEY=VALUE patches
./scripts/radiance-env.sh set RADIANCE_COUNTRY=IR \
    RADIANCE_FEATURE_OVERRIDES=force_track=eevee
```

The `poll` subcommand is useful after any `set` / `force-track` call —
otherwise the change only takes effect on the next adaptive config fetch
(can be minutes away). The script auto-detects whether to use `sudo` based
on the socket permissions; Windows uses a named pipe and is not supported
by this wrapper.

---

## 7. Testing

---

### 7.1 Unit & Widget Tests

Run all unit and widget tests:

```bash
flutter test test/
```

Run a single test file:

```bash
flutter test test/features/vpn/vpn_test.dart
```

Run with coverage:

```bash
flutter test --coverage
```

---

### 7.2 Integration Tests

Integration tests use the `integration_test` package with headless widget tests and in-memory fakes.

Run all integration tests:

```bash
flutter test integration_test
```

Run a single integration test file:

```bash
flutter test integration_test/private_server_flow_test.dart
```

---

### 7.3 Linux VPN Smoke Test

End-to-end VPN connect/disconnect test on Linux:

```bash
flutter test integration_test/vpn/linux_connect_smoke_test.dart \
  -d linux \
  --dart-define=DISABLE_SYSTEM_TRAY=true \
  --dart-define=ENABLE_IP_CHECK=true
```

---

## 8. Release & Publishing

Releases are triggered by pushing a Git tag. CI picks up the tag, determines the build type and target platforms from the tag format, builds all relevant platform artifacts, and publishes a GitHub release.

### Tag format

| Tag | Build type | Platforms |
|---|---|---|
| `v1.2.3` | Production | All |
| `v1.2.3-beta` | Beta | All |
| `v1.2.3-android` | Production | Android only |
| `v1.2.3-macos` | Production | macOS only |
| `v1.2.3-ios` | Production | iOS only |
| `v1.2.3-windows` | Production | Windows only |
| `v1.2.3-linux` | Production | Linux only |

### How to release

**All platforms — production:**

```bash
git tag v1.2.3
git push origin v1.2.3
```

**All platforms — beta:**

```bash
git tag v1.2.3-beta
git push origin v1.2.3-beta
```

**Single platform:**

```bash
git tag v1.2.3-android
git push origin v1.2.3-android
```

### Nightly builds

A nightly build runs automatically every day at 04:00 UTC from the default branch, building all platforms with `BUILD_TYPE=nightly`. No tag is required. The draft release is deleted after artifacts are uploaded to S3.

---

## 9. Auto-Updater

The app supports automatic updates on macOS and Windows using the [auto_updater](https://pub.dev/packages/auto_updater) package, which is a Flutter-friendly wrapper around the Sparkle update framework.

### How it works

On startup, the app downloads the `appcast.xml` feed hosted [in the repo](appcast.xml) and on S3. This file lists the latest version and the signed `.dmg` or `.zip` update files. The updater downloads the update and installs it via Sparkle.

### Generating the appcast

The `appcast.xml` is generated dynamically as part of the release process using a [Python script](scripts/generate_appcast.py):

```bash
python3 scripts/generate_appcast.py
```

The script:
1. Fetches releases and their associated `.dmg` and `.exe` files via the GitHub API
2. Signs each asset using the `auto_updater:sign_update` Dart CLI tool
3. Emits an [appcast.xml](appcast.xml) with signature, size, and version metadata
