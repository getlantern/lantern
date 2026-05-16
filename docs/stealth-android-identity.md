# Stealth Android identity profiles

Stealth Android builds can use a generated identity profile to change install-time
identity without a separate source tree. The profile is a Java properties file
consumed by `android/app/build.gradle`.

Normal builds keep the current identity:

- `applicationId`: `org.getlantern.lantern`
- app and launcher label: `Lantern`
- VPN session name: `LanternVpn`
- notification and quick settings tile labels: existing Lantern/VPN wording

## Generate a profile

Generate a fresh random identity:

```sh
python3 scripts/stealth/generate_android_identity.py \
  --output build/stealth/android-identity.properties
```

Generate a deterministic identity from a seed:

```sh
python3 scripts/stealth/generate_android_identity.py \
  --seed "release-2026-05-15" \
  --output build/stealth/android-identity.properties
```

The generated profile includes:

- `applicationId`
- `appLabel` and `launcherLabel`
- `identityLabel`, `identityProfileId`, and `identityMetadata`
- `vpnSessionName`
- notification channel/title/body/action labels
- quick settings tile labels
- manifest icon resource names and custom auth scheme

The generator defaults stealth profiles to the neutral Android resources
`@drawable/neutral_app_icon` and `@drawable/neutral_notification_icon`.

Generated profiles are build inputs and should not be committed.

## Build with a profile

Pass a profile directly:

```sh
ANDROID_IDENTITY_PROFILE=build/stealth/android-identity.properties \
  make android-apk-release
```

Or let `make` generate one automatically for a stealth build:

```sh
BUILD_TYPE=stealth make android-release-ci
```

Use `ANDROID_IDENTITY_SEED` when the CI run must be reproducible:

```sh
BUILD_TYPE=stealth ANDROID_IDENTITY_SEED="$GITHUB_RUN_ID" make android-release-ci
```

`BUILD_TYPE=stealth` defaults the generated profile path to
`build/stealth/android-identity.properties`, so the APK and AAB from the same
`make android-release-ci` invocation share one identity. Passing
`ANDROID_IDENTITY_SEED` regenerates that profile for the requested seed. For an
unseeded fresh random identity, pass `ANDROID_FORCE_IDENTITY_PROFILE=1`.

Gradle also accepts the profile as a project property:

```sh
cd android
./gradlew assembleRelease \
  -PandroidIdentityProfile=../build/stealth/android-identity.properties
```

## Profile schema

All keys are optional. Missing keys fall back to the normal Lantern values. To
install side by side with the normal app, set `applicationId`.

```properties
applicationId=app.clearnotes.a1b2c3d4
appLabel=Clear Notes
launcherLabel=Clear Notes
identityLabel=clear-notes-2f143e88f4
identityProfileId=clear-notes-2f143e88f4
identityMetadata={"generator":"android-identity-v1"}
vpnSessionName=Clear Notes Session
notificationChannelVpn=Connection
notificationChannelDataUsage=Usage
notificationTitle=Clear Notes
notificationConnectedText=Connection is active
notificationStartingText=Starting connection...
notificationDisconnectAction=Disconnect
quickTileActiveLabel=Connected
quickTileInactiveLabel=Disconnected
appIcon=@drawable/neutral_app_icon
appRoundIcon=@drawable/neutral_app_icon
notificationSmallIcon=@drawable/neutral_notification_icon
quickTileIcon=@drawable/neutral_notification_icon
appAuthScheme=clearnotes2f143e88
```

The Makefile passes `appAuthScheme` to Flutter as
`--dart-define=APP_AUTH_SCHEME=...` for Android release builds so Dart deep-link
handling accepts the same private scheme that Gradle writes into the manifest.

This ticket intentionally leaves broader manifest minimization to the related
manifest work. The identity profile exposes placeholders where this branch needs
them, but does not remove normal deep links or service declarations.
