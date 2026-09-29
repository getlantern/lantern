# Desktop update delivery

Lantern starts the update relay in the app process before configuring Sparkle or
WinSparkle. It does not require the VPN service or daemon IPC. Both the appcast
and its installer URLs use a loopback endpoint with a randomly generated path.
The relay serves only the configured Lantern feed and installers registered from
that feed.

## Transport

The relay tries HTTPS directly, then uses Radiance's independent domain-fronting
client on connection failures, 403s, or server errors. That client starts from
embedded configuration and keeps its own cache under `update-transport` in the
user's application support directory. The bypass dialer keeps these requests
outside the tunnel when its local proxy is available and uses ordinary sockets
when that proxy is unreachable.

For a fronted request, Radiance connects to a CDN front's IP address and sends the
provider's update-service alias inside the TLS connection. This avoids a direct
connection to the blocked update hostname. Embedded and cached configuration let
checks start without first fetching new configuration. Fronted delivery requires
a reachable front and a working CDN route to the update service.

Installer delivery uses the update server's `/releases/` route, which fetches
the bytes from S3. Legacy versioned S3 URLs in appcasts are mapped to this route,
so the device does not need to reach S3. Installer redirects back to S3 are
rejected. Staging also accepts signed GitHub fixtures from
`getlantern/lantern-update-fixtures`.

Installer responses stream through the relay with range and conditional-request
support. Header and idle-read deadlines bound stalled requests without imposing
a total timeout on slow downloads. Closing the relay cancels active requests.

## Native updater lifecycle

Sparkle and WinSparkle schedule checks, select versions, verify signatures,
install, and relaunch. The relay preserves version and signature metadata when
rewriting the feed, and passes installer bytes through unchanged. Lantern retries
unfinished relay/native setup and waits for native completion before allowing
another manual check.

## Test coverage

The pinned `getlantern/auto_updater` revision includes native delivery fixtures
for Sparkle and WinSparkle in `tests/native_delivery`. Its CI verifies that both
SDKs download through tokenized HTTP loopback URLs, accept signed bytes, and
reject invalid signatures. Those fixtures intercept installer handoff rather
than installing the app.

The [macOS](../.github/workflows/macos-auto-update-smoke.yml) and
[Windows](../.github/workflows/windows-auto-update-smoke.yml) auto-update
workflows build a signed beta fixture from the selected branch, with a build
number below the target in the staging appcast.
Sparkle or WinSparkle downloads and installs the target. The smoke checks its
signature and version, waits for the original process to exit, and verifies that
the updated app relaunches with a visible window.

Both workflows accept a `scenario` input:

- `baseline`: starts Lantern normally and checks for updates through the app menu.
- `core-unavailable`: holds core initialization indefinitely while the normal
  startup update check runs. The test verifies that core is still unavailable and
  no VPN bypass proxy is listening when the native updater offers an update.

The workflows replace the installed app and clear test data on their runners.
Diagnostics include the target version, Flutter log, native handoff, process IDs,
signatures, and screenshots. Both scenarios use the staging feed and its signed
GitHub fixtures; they do not test blocked endpoints or domain fronting.
