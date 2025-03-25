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

# Build and run the app on macOS

```
make macos-debug
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
