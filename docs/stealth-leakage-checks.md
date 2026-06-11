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

### `stealth` (base)

Checks for normal Lantern package, brand, library, service, and organization
identifiers; user-facing VPN strings; OAuth provider strings and method-channel
entry points; billing and subscription entry points; app-link hosts, custom
schemes, and deep-link paths; Lantern social/support URLs; and update feed and
release URLs.

### `stealth-vpn`

Brand-only policy for the de-branded full-featured VPN variant. Checks the
`lantern_identity` and `social_urls` categories only. Generic tokens such as
`oauth`, `stripe`, `billing`, and `VPN` are intentionally allowed — login,
payment, and VPN surfaces are retained in this variant. OAuth2 and the
`lantern://` deep-link scheme are excluded at source (via `//go:build !stealth`
build tags in `account/oauth.go`, `backend/oauth.go`, and `mobile_oauth.go`),
so they are absent from the binary for the correct reason — not merely
garble-encrypted. The `lantern_identity` tokens are case-insensitive substrings
that catch all brand variants (`lantern.io`, `lantern://`, `org.getlantern.*`,
etc.) without false positives on generic tokens.

### `stealth-novpn`

Extends `stealth` (full forbidden set) and also checks Android VPN/TUN surfaces
such as `android.net.VpnService`, `BIND_VPN_SERVICE`, `TunOptions`, and VPN
quick tile/service actions. Carries three narrow allowlist entries in
`forbidden_tokens.json` for irreducible third-party strings (`oauth` from
`pion/webrtc/v4` RFC 7635, `stripe` from proto field name, `/auth` from proto
file descriptor path) — see the allowlist entries for full rationale.

## Scanner limitations

`check_leakage` and raw `strings | grep` scan the post-garble binary. When a
Go package is in `GARBLE_GOGARBLE` scope, garble `-literals` encrypts string
literals at compile time, so brand strings in compiled-in garble packages are
absent from the static binary but present at runtime. A pass from
`check_leakage` alone is not sufficient evidence of brand removal for garbled
packages.

See `docs/stealth-builds.md` ("Garble string-literal obfuscation blind spot"
and "Standing nm -D brand-symbol gate") for the required complementary checks.

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
