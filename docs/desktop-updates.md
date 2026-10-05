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

Sparkle schedules recurring checks on macOS. On Windows, Lantern schedules a
check an hour after the previous update cycle finishes. WinSparkle's periodic
worker can stop after a failed request, so its timer stays disabled. Failed
Windows checks retry after 1, 5, and 15 minutes, then hourly until a check succeeds.
Resuming the app or reconnecting can bring a pending retry forward.

Manual and automatic Windows checks share the same guard. The guard stays held
while the native prompt or download is active and is released by the completion
callback. On macOS, Sparkle prevents overlapping checks within its native update
session, including while the feed is loading. Sparkle and WinSparkle handle
signatures, installation, and relaunch.

The relay preserves version and signature metadata when rewriting the feed and
passes installer bytes through unchanged. Lantern retries unfinished relay and
native updater setup.

## Test coverage

The pinned `getlantern/auto_updater` revision includes native delivery fixtures
for Sparkle and WinSparkle in `tests/native_delivery`. Its CI verifies that both
SDKs download through tokenized HTTP loopback URLs, accept signed bytes, and
reject invalid signatures. Those fixtures intercept installer handoff rather
than installing the app.

The [macOS](../.github/workflows/macos-auto-update-smoke.yml) and
[Windows](../.github/workflows/windows-auto-update-smoke.yml) auto-update
workflows build a signed beta fixture from the selected branch, with a build
number below the target in the selected appcast.
Sparkle or WinSparkle downloads and installs the target. The smoke checks its
signature and version, waits for the original process to exit, and verifies that
the updated app relaunches with a visible window.

Both workflows accept a `scenario` input:

- `baseline`: starts Lantern normally and checks for updates through the app menu.
- `core-unavailable`: holds core initialization indefinitely while the normal
  startup update check runs. The test verifies that core is still unavailable and
  no VPN bypass proxy is listening when the native updater offers an update.
- `core-unavailable-direct-blocked`: also maps the direct update and S3 hostnames
  to loopback for IPv4 and IPv6. The relay starts without cached fronting
  configuration and uses the published beta feed, whose hostname has a CDN
  fronting route. Both the feed and installer must remain reachable through that
  route while direct access is blocked.

The macOS workflow first tests the native UI driver against a small fixture
window. It uses the public Accessibility API to press Sparkle's install buttons
and detect the relaunched window. The active `Runner.Listener` needs Accessibility
approval in the runner's logged-in desktop session; System Events Automation
approval is not required.

The workflows replace the installed app and clear test data on their runners.
Diagnostics include the target version, Flutter log, native handoff, process IDs,
signatures, and screenshots. Baseline and stalled-core scenarios use the staging
feed and its signed GitHub fixtures. The blocked scenario uses the production
update hostname and checks the DNS block before launch, at the update offer, and
after relaunch. Script cleanup and an `always()` workflow step remove only the
hosts-file entries added by the test. A passing build alone does not validate
fronted delivery; the signed installation and relaunch checks must pass too.
