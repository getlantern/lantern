# Stealth build notes

Android stealth manifest minimization is opt-in through the Gradle project
property `STEALTH_MODE`. The Gradle task uses `-PstealthPython`, then `PYTHON`,
then `python3` to generate the filtered manifest, so Android stealth builds
require Python 3.8 or newer through one of those paths.

```sh
gradle -p android :app:assembleRelease -PSTEALTH_MODE=stealth-vpn
gradle -p android :app:assembleRelease -PSTEALTH_MODE=stealth-novpn
```

The filter runs on the AGP-merged manifest (after library AARs such as Stripe
and Google Play Billing have contributed their activities and services) so that
all library-injected manifest entries are available for removal.

`-PstealthNoVpn=true` is kept as a compatibility switch for older automation.
It only selects `novpn` mode when `STEALTH_MODE` is **not** set; if both
`STEALTH_MODE` and `-PstealthNoVpn` are unset, the build is a normal
non-stealth build. When `-PstealthNoVpn=true` and `STEALTH_MODE=stealth-vpn`
are both set, Gradle fails fast because the two inputs conflict. Prefer
`-PSTEALTH_MODE=stealth-novpn` for new build scripts.

`vpn` keeps the Android `VpnService` surface but removes app links, broad
package visibility, write-settings access, payment query declarations, wallet
metadata, boot receiver, and cleartext traffic allowance from the generated
manifest.

`novpn` applies the same filtering and also removes Android VPN service
components, quick-tile VPN controls, and VPN-related permissions.
Runtime code must still be compiled or gated separately so no-vpn builds do not
attempt to start removed services.
