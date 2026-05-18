# Stealth feature gates

Stealth artifacts disable high-identification product surfaces at compile time
with Dart environment defines. Normal builds remain unchanged.

## Build flags

Use either profile-style mode names or an explicit boolean flag:

```sh
flutter build apk --dart-define=STEALTH_MODE=stealth-vpn
flutter build apk --dart-define=STEALTH_MODE=stealth-novpn
flutter build apk --dart-define=STEALTH_MODE=true
flutter build apk --dart-define=STEALTH_BUILD=true
flutter build apk --dart-define=STEALTH_NO_VPN=true
```

`STEALTH_MODE=true` is kept as a compatibility alias for generic stealth
artifacts; profile-specific builds should prefer `stealth-vpn` or
`stealth-novpn`.

The app derives these gates from the stealth flag:

- `enableOAuth`
- `enablePayments`
- `enableStorePayments`
- `enableAppLinks`
- `enableSocialLinks`
- `enableAutoUpdate`

`STEALTH_NO_VPN=true` is the explicit no-VPN compatibility flag. It enables the
same feature gates as `STEALTH_BUILD=true` and is treated as stealth mode even
when `STEALTH_MODE` is not supplied.

## Disabled surfaces

Stealth builds hide or short-circuit:

- OAuth login buttons, callbacks, and SSO account deletion verification.
- Store purchase initialization, restore purchase, Google Play subscription
  management, Stripe/payment redirect entry points, and upgrade CTAs.
- Runtime app-link handling in Flutter.
- Follow-us, forum, alternate download, referral/social, and project-link
  surfaces.
- Desktop auto-update initialization, manual update checks, and appcast URL
  resolution.

Native manifest and entitlement removal is handled by the stealth manifest
filtering build step. Artifact leakage checks should still scan final APK/IPA
and desktop bundles for OAuth provider names, app-link hosts/schemes, billing
entry points, social URLs, and appcast/update URLs.
