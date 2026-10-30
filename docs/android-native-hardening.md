# Android native hardening (#3975)

Both gomobile build variants enable stack protection and FORTIFY for native
C/C++ code, plus full RELRO and a nonexecutable stack. Go's upstream
`runtime/cgo` stack-protector override remains intact.

App compiler flags cannot change the NDK's prebuilt `libc++_shared.so`.
`make android-hardened-libcxx` rebuilds the matching NDK runtime using the source
revision, Android patches and SHA-256 hashes in
`scripts/android/hardened-libcxx-sources.json`. CMake also prepares it for direct
Gradle builds. The builder verifies exported symbols, SONAME/dependencies,
hardening and 16 KB alignment, and links a C++ exception smoke program.
Receipts and licenses are in `bin/android/libcxx/<ABI>/`.

`libapp.so` is the Dart AOT snapshot. Flutter documents its absent canaries and
RELRO as [scanner false positives](https://docs.flutter.dev/reference/security-false-positives).
The artifact checker grants this exception only to the expected snapshot
exports without imports, GOT/PLT or relocations. It retains the raw findings
and still requires PIC, NX and no writable/executable load segments.

The Make targets check both ARM architectures in the AAR and final release
APK/AAB. Release CI retains JSON evidence, including library hashes and any
exceptions. Run the checks independently with:

```sh
python3 -m unittest discover -s scripts/ci -p 'verify_android_hardening_test.py'
python3 scripts/ci/verify_android_hardening.py \
  --aar bin/android/liblantern.aar \
  --aab build/app/outputs/bundle/release/app-release.aab
```

Device runtime validation and a retest of the Play-delivered build remain
necessary before closing the audit finding.
