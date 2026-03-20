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


# Developer Guide

## Prerequisites

All platforms require the following tools installed and available on your `PATH`:

- **Flutter 3.35.6** (stable channel) — The required version is pinned in `pubspec.yaml`. Install it from [flutter.dev](https://flutter.dev) or use a version manager such as [fvm](https://fvm.app). After installing Flutter, verify with `flutter doctor`.
- **Go 1.25.4** — The required version is declared in `go.mod`. Install from [go.dev/dl](https://go.dev/dl) or use a version manager such as [mise](https://mise.jdx.dev).
- **Git**

Platform-specific dependencies (Xcode, Android Studio, etc.) are described in each section below.

---

## Getting Started

After cloning the repository, install Flutter package dependencies:

```bash
flutter pub get
```

This resolves the Dart/Flutter packages declared in `pubspec.yaml` and writes dependency metadata to `.dart_tool/`. It must be run at least once before any build. Re-run it whenever `pubspec.yaml` or `pubspec.lock` changes (e.g., after pulling commits that add or update packages).

---

## Building for macOS

### One-time Xcode setup

If you have recently installed or updated Xcode, initialize the command-line tools before building:

```bash
sudo xcodebuild -runFirstLaunch
```

This accepts the Xcode license agreement and installs additional platform components. It only needs to be done once per Xcode installation; subsequent builds do not require it.

### Install build dependencies

The macOS build compiles native Go code into an `.xcframework` using `gomobile`. The following command installs `gomobile`, initializes it for the current Go toolchain version, and also installs tools needed for packaging release builds (`appdmg`, `flutter_distributor`, etc.):

```bash
make install-macos-deps
```

If you only need to run the app locally and do not need release packaging tools, you can install just `gomobile`:

```bash
make install-gomobile
```

### Build and run

Build the native Go framework (outputs to `macos/Frameworks/`):

```bash
make macos
```

Then run the Flutter desktop app:

```bash
flutter run -d macos
```

---
# Build and run the app on Linux (systemd daemon, no sudo)

1. Build Linux artifacts

```bash
make linux-release
```

2. Install the `.deb` (requires root only for install)

```bash
sudo apt install ./lantern-installer-*.deb
```

3. Check daemon status

```bash
systemctl status lanternd.service
```

4. Run Lantern app as your normal user

```bash
flutter run -d linux
```

Troubleshooting:

```bash
journalctl -u lanternd.service -n 200 --no-pager
```

Uninstall / cleanup:

```bash
sudo systemctl disable --now lanternd.service
sudo apt remove lantern
sudo rm -f /usr/lib/systemd/system/lanternd.service /usr/lib/lantern/lanternd
sudo systemctl daemon-reload
```

# Build and run the app on Windows

## Building for iOS

### Prerequisites

- Xcode (latest stable) with the iOS Simulator or a physical iOS device

### Install build dependencies

```bash
make install-ios-deps
```

This installs `gomobile`, initializes it if needed, and activates `flutter_distributor`.

### Build and run

Build the native iOS framework (outputs to `ios/Frameworks/`):

```bash
make ios
```

List available devices and simulators:

```bash
flutter devices
```

Run on a specific device using its ID from the previous command:

```bash
flutter run -d <deviceID>
```

---

## Building for Windows

The Windows build separates the backend (a Windows Service binary) from the Flutter UI. During development you can run the backend in console mode instead of registering it as a real service, which makes for a faster iteration loop.

### Quick dev loop

1. **Build the Windows service binary** (from an elevated PowerShell):

    ```powershell
    make windows-service-build
    ```

2. **Start the backend** in console mode:

    ```powershell
    .\bin\windows-amd64\lanternsvc.exe --console
    ```

3. **Build the native shared library:**

    ```bash
    make windows
    ```

4. **Run the Flutter desktop app:**

    ```bash
    flutter run -d windows
    ```

The Flutter app communicates with the service via a named pipe.

### Running as a real Windows Service

If you prefer to run the backend as a real Windows Service during development, use the [helper scripts](scripts/windows) from an elevated PowerShell.

---

## Building for Android

### Prerequisites

- **Java 17 or newer** — Required by Gradle. Install a JDK distribution such as [Eclipse Temurin](https://adoptium.net) and ensure `JAVA_HOME` points to it. You can verify with `java -version`.
- **Android Studio** (or the standalone [Android command-line tools](https://developer.android.com/studio#command-line-tools-only)) — provides the `sdkmanager` utility used in the next step.

### Install Android SDK components

```bash
make install-android-sdk
```

This installs the Android platform, build tools, NDK, and CMake at the versions defined by the `ANDROID_*` variables at the top of the `Makefile`. It also accepts the SDK licenses automatically.

After the NDK is installed, set the following environment variables so the build tools can locate it:

```bash
export ANDROID_NDK_HOME=$ANDROID_SDK_ROOT/ndk/27.0.12077973
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
export NDK_HOME=$ANDROID_NDK_HOME
```

Rather than adding these to your global shell profile, consider managing them with a repo-local config file so they only apply in this project and are not committed to version control:

- **[direnv](https://direnv.net)**: place the `export` lines above in a `.envrc` file at the repo root, then run `direnv allow`. Add `.envrc` to `.git/info/exclude` (or your global gitignore) to keep it untracked.
- **mise**: add an `[env]` block to a `.mise.local.toml` file at the repo root. `*.local.toml` files are intended for personal overrides and should not be committed. See the [mise environment variables docs](https://mise.jdx.dev/environments/) for syntax.

### Install build dependencies (gomobile)

`gomobile` compiles the Go backend into an Android AAR library. The following command installs `gomobile` and `gobind`, then runs `gomobile init` (only on first run or after a Go toolchain upgrade):

```bash
make install-android-deps
```

### Build

Build the debug APK:

```bash
make android-debug
```

This first compiles the native Go libraries into `android/app/libs/liblantern.aar`, then invokes Gradle via Flutter to assemble the APK. The first build takes longer because it compiles all Go dependencies; subsequent builds are incremental.

The output APK is at:

```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## Running integration tests

We use the `integration_test` package with headless widget tests and in-memory fakes.

### Run all integration tests

```bash
flutter test integration_test
```

### Run a single test file

```bash
flutter test integration_test/private_server_flow_test.dart
```

---
### Run Linux VPN connect/disconnect smoke test

```bash
flutter test integration_test/vpn/linux_connect_smoke_test.dart -d linux --dart-define=DISABLE_SYSTEM_TRAY=true --dart-define=ENABLE_IP_CHECK=true
```

# Auto-Updater Integration

The app supports automatic updates on macOS and Windows, using the [auto_updater](https://pub.dev/packages/auto_updater) package, which is a Flutter-friendly wrapper around the Sparkle update framework.

On startup, the app downloads the `appcast.xml` feed, hosted [in the repo](appcast.xml) and on S3. This file lists the latest version and the signed `.dmg` or `.zip` update files. The updater downloads the update and installs it via Sparkle.

We generate the `appcast.xml` dynamically using a [Python script](scripts/generate_appcast.py) as part of our release process:

```bash
python3 scripts/generate_appcast.py
```

The script works by fetching releases and their associated `.dmg` and `.exe` files via the GitHub API, signing each asset using the `auto_updater:sign_update` Dart CLI tool, and emitting an [appcast.xml](appcast.xml) with signature, size, and version metadata.
