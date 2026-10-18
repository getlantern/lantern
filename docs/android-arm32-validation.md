# Android ARM32 validation

The AAR, debug APKs and Play AAB package both ARM32 and ARM64, with matching
targets across gomobile, Flutter and Gradle. The sideload release ships one APK
per ABI (`lantern-installer[-<type>].apk` for ARM64, `...-armv7.apk` for ARM32)
so ARM64 users don't download 32-bit libraries; `-Plantern.abis` narrows Gradle
packaging for each build. Artifact checks require both architectures in the AAR
and AAB, and exactly one in each sideload APK.

## Failure and fix

The shipped [9.1.9-beta APK](https://github.com/getlantern/lantern/releases/download/v9.1.9-beta/lantern-installer-beta.apk),
built with Go 1.26.2, reproduces a native startup crash on physical Galaxy A10,
Android 10/API 29, kernel 4.4.177. The matching library and tombstone identify
`SIGSYS / SYS_SECCOMP` in `runtime.futex_time64`: ARM syscall 422 is blocked
before Go's `ENOSYS` fallback can run. [Go #77621](https://github.com/golang/go/issues/77621)
fixes syscall selection on older kernels; the pinned Go 1.26.9 includes it.
The exact 9.1.11 Play artifact reported in [#8821](https://github.com/getlantern/lantern/pull/8821)
was unavailable, so the reproduced control is specifically 9.1.9.
Its verified APK SHA-256 is
`bc5b732ca421a4e9783d1e5f357a6d0317185ac127f2edc0ad99b5c935a0dbfc`.

Physical testing also exposed gVisor TUN teardown retaining Android's VPN
network after disconnect. The shared [sing-tun backport](https://github.com/getlantern/sing-tun/commit/5448fbd8b70bb2057bd1f6f2148830fde4f18f85)
preserves `Attach(nil)` through its filter so the packet reader stops before
closing the descriptor. Reconnect passes with that fix.

## Verified evidence

The fixed application/native dependency was tested at `f459a2e7d` on 2026-10-17.

| Check | Evidence | Result |
| --- | --- | --- |
| Historical startup control | [Run 39028384967](https://github.com/getlantern/lantern/actions/runs/39028384967) | Expected native crash; tombstone confirms syscall 422 |
| Build and regressions | [Run 39029930006](https://github.com/getlantern/lantern/actions/runs/39029930006) | ABI checks, old/fixed Go seccomp control, TUN teardown, Android tests and dual release APK/AAB passed |
| Physical ARM32 Galaxy A10/API 29 | [Run 39029932139](https://github.com/getlantern/lantern/actions/runs/39029932139) | Startup, VPN IP change/restoration and reconnect transitions passed |
| Physical ARM64 Pixel 8/API 34 | [Run 39029934101](https://github.com/getlantern/lantern/actions/runs/39029934101) | The same three smoke tests passed |

A10 logs confirm `is64Bit=false`, ARM32 ABIs and no supported 64-bit ABI.
This satisfies the agreed genuine ARM32 runtime target; an exact Android 9 or
Samsung affected-model match is not required. Debug smoke does not establish
release-mode startup, traffic after reconnect, upgrades or data preservation.

TECNO-BF6/API 31 was inconclusive in both matrices (`Internal System Error 3`,
three infrastructure attempts each), leaving the ARM32 workflow red despite
A10 passing. Firebase follow-up is deferred: project `lantern-android`, matrices
`matrix-33gd00r96a010` and `matrix-3v5mdx7hvfkgs`. There is no TECNO app result.

## Build and test

```sh
gh workflow run android-compile-check.yml --ref atavism/android-32 -f build_candidate=true
make android-debug-ci
make android-release-ci
```

The optional CI artifact build includes APK/AAB checksums, uses debug signing
and does not publish. Local release builds use configured signing credentials,
falling back to a debug key. The standalone runtime control
requires x86_64 Linux with 32-bit execution, gcc, Go and Python:

```sh
python3 scripts/android/test-runtime-seccomp.py
```

Run the focused physical-device suite through CI:

```sh
gh workflow run firebase-test-lab.yml --ref atavism/android-32 \
  -f test_target=integration_test/android_architecture_smoke_test.dart \
  -f devices='model=a10,version=29,locale=en,orientation=portrait' \
  -f instrumentation_args='lanternExpectedAbi=armeabi-v7a,lanternExpectedSdk=29,lanternRequire32BitOnly=true'
```

For ARM64, select its physical model/API, use `lanternExpectedAbi=arm64-v8a`
and omit `lanternRequire32BitOnly`. Test the same revision on both devices.
Instrumentation checks process bitness and OS ABIs before activity launch;
forcing a 32-bit process on a 64-bit OS is insufficient. Retain test XML/logcat,
device fingerprint/kernel and artifact identity (source, hashes, versions,
signer and toolchains). Future FTL runs record `tested-artifact-identity.json`.

## Validation still needed

These checks have not yet been verified:

- On genuine ARM32 and ARM64 devices, verify release-mode installation/startup,
  VPN traffic, IP change/restoration and traffic after reconnect.
- Upgrade in place from a compatible-signed predecessor without uninstalling or
  clearing storage; verify account/session, entitlement and settings persist.
- In Play Console preview, verify the release AAB includes Galaxy J7 Neo on
  Android 9, Galaxy M02s/A02s on Android 12, and ARM64 models.
