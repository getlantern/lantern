# Stealth Build Profile

Stealth builds use the normal Lantern source tree. The build is switched by
passing either a generated profile mode or a private profile JSON file into the
existing Makefile targets.

Normal builds are unchanged when neither `STEALTH_MODE` nor `STEALTH_PROFILE`
is set.

## Generate a Profile

Generate a private profile under `build/stealth/`:

```sh
make stealth-profile STEALTH_MODE=stealth-vpn
```

Supported modes are:

- `stealth-vpn`
- `stealth-novpn`

The generated profile includes:

- `mode`
- `packageName`
- `appName`
- `sessionName`
- `goObfuscationSeed`
- `denylistVersion`

Override generated values with Make variables:

```sh
make stealth-profile \
  STEALTH_MODE=stealth-vpn \
  STEALTH_PACKAGE_NAME=org.example.client.s123 \
  STEALTH_APP_NAME=Client \
  STEALTH_SESSION_NAME=ClientVpn \
  STEALTH_GO_OBFUSCATION_SEED=0123456789abcdef \
  STEALTH_DENYLIST_VERSION=1
```

Use an existing private profile:

```sh
make stealth-profile STEALTH_PROFILE=/secure/profiles/client.json
```

## Build With a Profile

Android build targets generate or normalize the profile before invoking Flutter:

```sh
make android-release STEALTH_MODE=stealth-vpn
make android-release STEALTH_PROFILE=/secure/profiles/client.json
```

The Makefile writes:

- `build/stealth/profile.json`: private normalized profile for support/debugging
- `build/stealth/profile.inputs`: private Make cache key for profile inputs
- `build/stealth/dart-defines.json`: Flutter `--dart-define-from-file` input
- `build/stealth/artifact-metadata.json`: private CI artifact metadata
- `build/stealth/go-tags-suffix.txt`: Go build tag suffix consumed by Make

Treat the entire `build/stealth/` directory as private and do not publish these
files in public release artifacts. They contain profile values that identify a
build stream. Dart defines, metadata, and the Make cache key omit the raw Go
obfuscation seed; metadata and the cache key include seed hashes for change
detection and support correlation.

## Android Plumbing

`android/app/build.gradle` reads the normalized profile from a
`-PstealthProfile=/path/to/profile` Gradle property, or from
`ORG_GRADLE_PROJECT_stealthProfile` when invoked through Flutter/Make. The
legacy `STEALTH_PROFILE` environment variable remains a fallback for manual
non-daemon Gradle invocations.

Gradle profile loading only affects Android manifest and `BuildConfig` values.
It does not populate Dart constants by itself. Use the Make targets, or pass
the generated `build/stealth/dart-defines.json` explicitly with
`flutter build --dart-define-from-file=build/stealth/dart-defines.json`, so
`AppBuildInfo` and `AppSecrets` see the same profile values as Gradle.

The profile sets:

- Android `applicationId`
- Android manifest app label
- `BuildConfig.STEALTH_*` constants

For stealth builds the Android namespace becomes `foundation.bridge` (normal
builds keep `org.getlantern.lantern`); see the `namespace` assignment in
`android/app/build.gradle`. No separate source tree is needed.

## Dart and Go Plumbing

Flutter receives profile values through `--dart-define-from-file`, exposed in
`AppBuildInfo.stealth*` constants. Go builds receive a tag suffix from
`generate_profile.py` (`go_tags_suffix`):

- `stealth` (all stealth builds)
- `novpn` (added only for `stealth-novpn` mode)

## Package Name Migration Tradeoff

Generated stealth profiles use a per-profile Android package name by default.
Android treats each package name as a different app, so a build with a new
`packageName` does not update an existing install and does not share that app's
data directory. Release and support workflows need to keep the private profile
for each distributed build so they can identify which package name, app label,
session name, denylist version, and Go obfuscation seed were used.
