# Stealth No-VPN Android Proxy Build

The no-VPN Android build removes Lantern's `VpnService` manifest component and
quick settings VPN tile from the selected build manifest. It starts Radiance in
its existing local proxy mode instead of creating an Android TUN interface.

## Build

Use the dedicated Make target:

```sh
make android-stealth-novpn-release
```

The target passes both build-time switches:

- `ORG_GRADLE_PROJECT_stealthNoVpn=true` selects
  `android/app/src/main/AndroidManifest.novpn.xml` and sets
  `BuildConfig.STEALTH_NO_VPN`.
- Release builds also enable `proguard-stealth-novpn.pro`, which fails the
  build if R8 cannot discard the Android `VpnService` and quick tile service
  classes from the no-VPN artifact.
- `--dart-define=STEALTH_NO_VPN=true` hides VPN-only UI and shows proxy setup
  instructions.

Outputs are named:

- `lantern-installer-stealth-novpn.apk`
- `lantern-installer-stealth-novpn.aab`

When `BUILD_TYPE` is not `production`, the build type remains in the installer
name before `-stealth-novpn`.

## Runtime Behavior

The Android service sets:

```text
RADIANCE_USE_SOCKS_PROXY=true
RADIANCE_SOCKS_ADDRESS=127.0.0.1:14986
```

Radiance uses a sing-box `mixed` inbound for this mode, so the same loopback
listener accepts SOCKS5 and HTTP CONNECT clients:

```text
Host: 127.0.0.1
Port: 14986
SOCKS5: 127.0.0.1:14986
HTTP CONNECT: 127.0.0.1:14986
```

Apps and browsers must be configured manually when they support per-app proxy
settings. This build does not route full-device traffic, request Android VPN
permission, expose split tunneling controls, or register Lantern as Android's
active VPN.

## Known Limitations

### Loopback proxy access control (experimental)

The local proxy listener on `127.0.0.1:14986` has **no authentication** in
this release. Any local process or application on the device can use it as a
SOCKS5/HTTP CONNECT proxy without credentials.

**Threat model:** a hostile application co-installed on the device could
route its traffic through the Lantern proxy without user consent, potentially
leveraging Lantern's circumvention capability or incurring data costs for the
user. This relates to the threat model documented in issue #3573.

**Status:** experimental until radiance-side SOCKS authentication lands.
Do not ship this build in a production context where hostile local apps are
a realistic threat before the access control gap is closed.

**Mitigation roadmap:** SOCKS5 username/password auth or a Unix socket
with filesystem permissions is planned for a future radiance release.
