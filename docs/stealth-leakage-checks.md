# Stealth Leakage Checks

`scripts/stealth/check_leakage.py` scans built stealth artifacts for normal
Lantern identifiers. It accepts APK, AAB, ZIP-like archives, and unpacked build
directories. Archive entries are scanned recursively, and string matching checks
UTF-8, UTF-16LE, and UTF-16BE encodings.

Run the default stealth check:

```sh
make stealth-leakage-check \
  STEALTH_LEAKAGE_PATHS="path/to/app.apk path/to/app.aab"
```

Run the stricter no-VPN variant:

```sh
make stealth-novpn-leakage-check \
  STEALTH_LEAKAGE_PATHS="path/to/app.apk"
```

If the configured targets are absent, the Make targets skip successfully. This
keeps normal builds and ordinary CI runs from failing on stealth-only checks.

## Modes

The forbidden-token config lives at
`scripts/stealth/forbidden_tokens.json`.

`stealth` checks for:

- normal Lantern package, brand, library, service, and organization identifiers
- user-facing VPN strings
- OAuth provider strings and method-channel entry points
- billing and subscription entry points
- app-link hosts, custom schemes, and deep-link paths
- Lantern social/support URLs
- update feed and release URLs

`stealth-novpn` extends `stealth` and also checks Android VPN/TUN surfaces such
as `android.net.VpnService`, `BIND_VPN_SERVICE`, `TunOptions`, and VPN quick
tile/service actions.

## Allowlists

Each mode supports an `allowlist` in the JSON config. Allowlist entries can
match by `token`, `category`, `location` glob, and `encoding`. Example:

```json
{
  "token": "Lantern",
  "location": "*.SF",
  "reason": "example only"
}
```

Keep allowlist entries narrow and mode-specific so real leaks still fail the
scan.
