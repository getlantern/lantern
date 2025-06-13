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


# Setup project

* [Flutter (3.32.XX)](https://flutter.dev)
* [Android Studio](https://developer.android.com/studio?_gl=1*1wowe6v*_up*MQ..&gclid=Cj0KCQjw6auyBhDzARIsALIo6v-bn0juONfkfmQAJtwssRCQWADJMgGfRBisMNTSXHt5CZnyZVSK2Y8aAgCmEALw_wcB&gclsrc=aw.ds) (Android Studio Jellyfish | 2023.3.1 Patch 1) 
* [gomobile](https://github.com/golang/go/wiki/Mobile#tools)
* [Xcode](https://developer.apple.com/xcode/resources/)
* [Git](https://git-scm.com/downloads)
* [Android NDK](#steps-to-run-the-project)
    * NDK should be version 26.x, for example 26.0.10792818.


# Build and run the app on macOS

```
make macos
make ffigen
flutter run -d macos
```

# Build and run the app on iOS

1. Install Go and gomobile

```
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
```

2. Build and run on an emulator or physical device

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

# Auto-Updater Integration

The app supports automatic updates on macOS and Windows, using the [auto_updater](https://pub.dev/packages/auto_updater) package, which is a Flutter-friendly wrapper around the Sparkle update framework.


On startup, the app downloads the appcast.xml feed, hosted [in the repo](appcast.xml) and on S3. This file lists the latest version and the signed .dmg or .zip update files. The updater downloads the update and installs it via Sparkle.

We generate the appcast.xml dynamically using a [Python script](scripts/generate_appcast.py) as part of our release process:

```
python3 scripts/generate_appcast.py
```

The script works by fetching releases, the associated .dmg and .exe files, via the GitHub API, signing each asset using the `auto_updater:sign_update` Dart CLI tool, and emitting an [appcast.xml](appcast.xml) with signature, size, and version metadata.
