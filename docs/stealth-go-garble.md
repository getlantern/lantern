# Stealth Go/native obfuscation

Stealth Go/native builds are opt-in. Normal Makefile targets continue to use
`go build` and `gomobile bind` directly.

## Inputs

- `GARBLE_SEED` or `STEALTH_GARBLE_SEED` is required for every obfuscated
  target. Use a base64-encoded seed from the stealth profile so support can
  reproduce the build and use `garble reverse` when needed.
  `GARBLE_SEED=random` is acceptable only for local, unreproducible smoke
  builds.
- `GARBLE_FLAGS` defaults to `-literals`. Add `-tiny` only after accepting the
  loss of useful panic and stack trace output.
- `GARBLE_LDFLAGS` defaults to `-w -s -buildid=` to strip symbol/debug tables
  and the Go build ID from obfuscated artifacts.
- `GARBLE_GOGARBLE` is optional. Leave it unset to use garble's default package
  selection. If a dependency is incompatible, set it to a comma-separated list
  of package path globs, for example
  `github.com/getlantern/*,github.com/sagernet/*`.

Treat release seeds as private support material. The Makefile suppresses command
echo for seed-bearing garble invocations, but release automation should still
keep the profile seed in a secret store alongside any private release metadata
needed for `garble reverse`. Record the exact `GARBLE_VERSION` and Go toolchain
version with each release; the Makefile defaults `GARBLE_VERSION` to `latest`,
which is convenient locally but not enough to reproduce a support build later.

Install garble:

```sh
make install-garble
```

## Android

Build the Android AAR with garble and then produce the APK/AAB:

```sh
STEALTH_GARBLE_SEED="$PROFILE_GARBLE_SEED" make android-release-ci-obfuscated
```

`gomobile bind` invokes `go build` internally, so the obfuscated target prepends
`scripts/garble-go` to `PATH`. That wrapper delegates non-build commands to the
real Go binary and runs only gomobile's internal `go build` through `garble`.

Reusable workflow callers can opt in without changing normal Android releases:

```yaml
jobs:
  build-android-stealth:
    uses: ./.github/workflows/build-android.yml
    secrets: inherit
    with:
      version: ${{ needs.set-metadata.outputs.version }}
      build_type: stealth
      installer_base_name: lantern-installer
      obfuscate_go: true
```

The workflow consumes `secrets.STEALTH_GARBLE_SEED` when `obfuscate_go` is true.
This workflow does not generate Android app identities or stealth profiles.

## Other native targets

Linux shared library:

```sh
STEALTH_GARBLE_SEED="$PROFILE_GARBLE_SEED" make linux-obfuscated
```

Linux daemon:

```sh
STEALTH_GARBLE_SEED="$PROFILE_GARBLE_SEED" make lanternd-linux-amd64-obfuscated
STEALTH_GARBLE_SEED="$PROFILE_GARBLE_SEED" make lanternd-linux-arm64-obfuscated
```

Desktop C shared library for a specific platform:

```sh
STEALTH_GARBLE_SEED="$PROFILE_GARBLE_SEED" \
  GOOS=darwin GOARCH=arm64 LIB_NAME=bin/macos-arm64/liblantern.dylib \
  make desktop-lib-obfuscated
```

## ABI and support constraints

These boundaries are externally visible and their public names cannot be
obfuscated without breaking consumers:

- Gomobile binding packages in `GOMOBILE_REPOS`:
  `github.com/sagernet/sing-box/experimental/libbox`,
  `./lantern-core/mobile`, and `./lantern-core/utils`. Java/Kotlin bindings
  are generated from exported Go APIs, and garble currently keeps exported
  methods/functions visible.
- Desktop FFI package `./lantern-core/ffi`. Every `//export` function in
  `lantern-core/ffi/ffi.go` is a C ABI symbol used by Flutter FFI and generated
  headers; examples include `setup`, `startVPN`, `stopVPN`, `login`, `logout`,
  and `freeCString`.
- Crash and support tooling. `lantern-core/utils.RunOffCgoStack` records
  `runtime/debug.Stack`; garble `-tiny` removes runtime panic and trace output,
  so it should not be the default for supportable builds.

Validation before shipping a stealth artifact should include Android connect,
auth, config fetch, and proxy/no-VPN smoke tests, plus a check that protobuf
marshal/unmarshal paths and gomobile exported calls still work with the selected
`GARBLE_GOGARBLE` scope.
