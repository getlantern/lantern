# AGENTS.md

The Lantern client: Flutter UI in `lib/`, Go core in `lantern-core/` (FFI on desktop, gomobile on mobile, both into `getlantern/radiance`), and native code in `macos/`, `ios/`, `android/`, `windows/`, `linux/`.

## Build and test

- Go: `CGO_ENABLED=1 go test -tags with_gvisor,with_quic,with_wireguard,with_utls,with_grpc ./...`
- Flutter: `make pubget && make gen`, then `flutter analyze` and `flutter test`.
- FFI bindings: `make ffigen` regenerates `lib/lantern/lantern_generated_bindings.dart`. Never hand-edit it.
- Swift: `make macos-unit-tests`, `make ios-compile-check`. Android: `./gradlew :app:testDebugUnitTest`.
- Dependency bumps (radiance, lantern-box, sing-box-minimal): run `go mod tidy` and commit `go.mod` and `go.sum` together.

## Review focus

These bug classes have shipped here, most frequent and severe first. Check a diff against each class that applies to the files it touches.

1. **Crashes at the CGo/gomobile boundary** (`lantern-core/ffi/`, `lantern-core/mobile/`, `lantern-core/utils/gostack.go`). Pointer-rich values on the cgo callback stack panic. Invalid UTF-8 or a typed-nil error reaching gomobile aborts the app in the ObjC bridge (#8541, #8635, #8989).
   - Check that every new `//export` returning `*C.char` runs its body in `runOnGoStack`.
   - Check that every gomobile export goes through `withCore`/`withCoreR` or `utils.RunOffCgoStack`, and that no raw upstream error crosses the boundary.
   - Check that recovery keeps `errors.Is`/`errors.As` working.
2. **Network Extension wedges and blackholes** (`macos/PacketTunnel/`, `ios/Tunnel/`, `macos/Runner/VPN/`). Semaphore bridges around `setTunnelNetworkSettings` deadlocked. A second utun opened over a live one. A failed restart was swallowed while the system showed "connected" (#8515, #8965, #9007, #9080).
   - Check that `semaphore.wait()` on an NE or cooperative queue has a deadline.
   - Check that errors are thrown or propagated, not logged and returned.
   - Check that start paths tear down the existing tunnel first and that old monitors are cancelled.
   - Fixes are usually needed in both `ios/Tunnel` and `macos/PacketTunnel`, so question a diff that changes only one.
3. **iOS start deadline and NE memory cap.** iOS kills the provider if `startTunnel` hasn't returned in about 7.5s, and the extension has a jetsam cap of roughly 50 MB (#8993, #8971).
   - Check that there is no network or config fetch on the `startTunnel` path.
   - Check for unbounded allocation in the extension (archives, outbound lists).
   - Check that new periodic work in the extension is rate-bounded, because battery cost is a regression too.
4. **Android VPN service lifecycle** (`android/.../service/LanternVpnService.kt`, `VpnStartGate.kt`, `PlatformInterfaceWrapper.kt`). Crash loops on Connect, JNI aborts, ANRs in `onDestroy`, and start/stop races that left the VPN latched (#8947, #8948, #9085).
   - Check that Kotlin methods called from Go never throw (return null instead).
   - Check that every `launch {}` has a `CoroutineExceptionHandler` and that nothing blocks the main thread.
   - Check that every start or stop entry point goes through `VpnStartGate`.
   - Check that blocking JNI calls use `async` + `withTimeout`, because a plain `withTimeout` doesn't interrupt blocking JNI.
5. **Dart parsing that throws on upstream JSON** (`lib/core/models/`). A lantern-box shape change threw out of `fromJson` and wiped the whole server list (#8929, #8412).
   - Check that radiance and lantern-box fields are parsed tolerantly, per entry.
   - A dependency bump that changes a JSON shape needs the Dart change in the same PR.
6. **UI state drifting from VPN and account state** (`lib/features/vpn/provider/`, `lib/features/home/`). The toggle acted on a different state than the one shown, and account data was lost on refresh (#8887, #9091, #9102).
   - Check that UI state is read from the status stream, not inferred locally.
   - Check that Pro checks use `UserDataProX.isPro`/`isExpired` only.
7. **OS, ABI, and toolchain floors.** Missing ABIs crashed at launch, and Go or Sparkle bumps raised the minimum macOS above the declared target (#8726, #8821, #9083).
   - Check that ABI lists in the `Makefile` and `android/app/build.gradle` agree.
   - Check that new Android APIs are guarded by `SDK_INT`.
   - Check that toolchain and framework bumps are checked against the declared minimum OS.
8. **macOS system-extension upgrades** (`macos/Runner/VPN/SystemExtensionManager.swift`, `release.yml`). Check that `CFBundleVersion` only increases and that every `OSSystemExtension` result, including `willCompleteAfterReboot`, leads to activation (#8628, #8614).
9. **Version stamping** (`Makefile`, workflows). An empty version caused config 400s, so check any change to `-X` ldflags paths or how the version is derived (#8677, #8539, #8865).
10. **Windows installer and service lifecycle** (`windows/packaging/exe/inno_setup.iss`, `lantern-core/cmd`). Lost legacy installs, ARM64 VCRedist detection, and a service that never restarted (#8576, #9127, #9012).

## Contracts a diff can silently break

- **Report-issue keys.** The dropdown keys in `lib/features/report_issue/report_issue.dart` must match `parseIssueType` in `lantern-core/core.go` and `assets/locales/en.po`. `TestIssueOptionsMatchParser` enforces this (#9023).
- **FFI.** `//export` signatures in `lantern-core/ffi/` must match the generated bindings. Dart callers free returned C strings.
- **Platform channels.** Method and event channel names (`org.getlantern.lantern/method`, `/status`, `/logs`, `/app_events`, …) are string literals duplicated across `lib/lantern/lantern_platform_service.dart`, the Android handlers, and the iOS/macOS Runners. Nothing checks that they match.
- **radiance.** A radiance bump can change the IPC API and JSON shapes. On iOS the extension sends an empty device ID so radiance resolves the shared one (#8936). Smart-routing rule detours must match outbound tags (`ai-domains` vs `sr-ai-domains`).
- **Purchases** (`lib/features/purchase*`). Store routing differs by region: Play Billing doesn't work for CN users (#9028).
