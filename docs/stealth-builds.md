# Stealth build notes

Android stealth manifest minimization is opt-in through the Gradle project
property `STEALTH_MODE`. The Gradle task uses `-PstealthPython`, then `PYTHON`,
then `python3` to generate the filtered manifest, so Android stealth builds
require Python 3 through one of those paths.

```sh
gradle -p android :app:assembleRelease -PSTEALTH_MODE=vpn
gradle -p android :app:assembleRelease -PSTEALTH_MODE=novpn
```

`vpn` keeps the Android `VpnService` surface but removes app links, broad package
visibility, write-settings access, payment query declarations, wallet metadata,
and cleartext traffic allowance from the generated manifest.

`novpn` applies the same filtering and also removes Android VPN service
components, quick-tile VPN controls, boot receiver, and VPN-related permissions.
Runtime code must still be compiled or gated separately so no-vpn builds do not
attempt to start removed services.
