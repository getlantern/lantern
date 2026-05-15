# Stealth Android icons

Stealth Android variants can generate a neutral launcher icon set from a
private per-variant seed. Normal builds keep the existing launcher icons.

## Generate Locally

```sh
make stealth-android-icons STEALTH_ICON_SEED="$PRIVATE_VARIANT_ICON_SEED"
```

This writes Android resources under
`android/app/build/generated/stealth-icons/res`:

- adaptive launcher icon: `@mipmap/stealth_ic_launcher`
- adaptive round launcher icon: `@mipmap/stealth_ic_launcher_round`
- foreground vector: `@drawable/stealth_launcher_foreground`
- notification icon candidate: `@drawable/stealth_notification_icon`
- private metadata: `stealth-icon-metadata.json`

The metadata stores only the seed hash, not the raw seed.

## Build Wiring

Android Gradle reads `STEALTH_ICON_SEED` or `-PstealthIconSeed=...`. When a
seed is present, the manifest placeholders switch the app icon and round icon
to the generated resources:

```sh
STEALTH_ICON_SEED="$PRIVATE_VARIANT_ICON_SEED" make android-apk-release
```

Without a seed, the placeholders resolve to the existing `@mipmap/ic_launcher`
and `@mipmap/ic_launcher_round` resources.

## Release Policy

Use a different private icon seed for every distributed stealth variant. Keep
the seed and `stealth-icon-metadata.json` with the private build profile so
support can correlate a report with the shipped visual identity. Do not publish
the seed or metadata with public artifacts.

The generated icons are intentionally generic geometric utility icons. If design
provides a curated pool later, the same Gradle placeholder path can select
pre-rendered resources by variant ID instead of procedural output.
