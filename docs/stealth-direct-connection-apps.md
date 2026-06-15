# Stealth direct-connection app exclusions

`STEALTH_DIRECT_CONNECTION_APPS=true` changes Android package-name split
tunneling into a local direct-connection exclusion list for stealth VPN builds.
Normal builds keep the existing lantern-core split-tunnel storage and behavior.

## Behavior

- Defaults are shipped in `assets/stealth/default_exclusions.json`.
- The Android app loads those defaults from Flutter assets and stores user edits
  in `SharedPreferences`.
- Selected package names are applied to each new `VpnService.Builder` with
  `addDisallowedApplication`, so those apps connect outside the VPN tunnel.
- User additions and removals are editable through the existing app selection
  screen. Changes apply on the next reconnect because Android does not update
  `VpnService.Builder` disallowed-app rules in place.
- Website/domain split tunneling is hidden in this stealth UI mode because this
  ticket only protects Android apps that can inspect local VPN state.

## Build input

Pass the same define to Flutter and Gradle:

```sh
flutter build apk \
  --dart-define=STEALTH_DIRECT_CONNECTION_APPS=true
```

The Android Gradle file reads Flutter `dart-defines`, environment variables,
and project properties in that order. CI may also use:

```sh
STEALTH_DIRECT_CONNECTION_APPS=true make android-release-ci
```

## Updating defaults

The first default list is based on the RKS/Airtable dataset referenced by the
stealth epic. Each entry must include:

- `package_name`: lower-case Android package name.
- `display_name`: user-readable app name for review.
- `reason_flags`: list of detection reasons, currently `rks_vpn_detection`.
- `source`, `confidence`, and `version` metadata for support review.

Run the asset test after edits:

```sh
flutter test test/features/split_tunneling/default_exclusions_asset_test.dart
```
