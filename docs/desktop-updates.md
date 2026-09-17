# Desktop update delivery

Lantern starts the update relay in the app process before configuring Sparkle or
WinSparkle. It does not require the VPN service or daemon IPC. Both the appcast
and its installer URLs point to a random, per-process loopback endpoint. Only
artifacts registered by the configured Lantern feed can be requested.

The relay tries HTTPS directly, then uses Radiance's independent domain-fronting
client on connection failures, 403s, or server errors. That client starts from
embedded configuration and keeps its own cache under `update-transport` in the
user's application support directory. The bypass dialer keeps these requests
outside the tunnel when its local proxy is available and uses ordinary sockets
when that proxy is unreachable.

For a fronted request, Radiance connects to a CDN front's IP address and sends the
provider's update-service alias inside the TLS connection. This avoids a direct
connection to the blocked update hostname. The update server fetches installer
bytes from S3, so the device does not need to reach S3 either. Embedded and cached
fronting configuration let checks start without first fetching new configuration.
Delivery still needs a reachable front and a working route from that CDN to the
update service; it cannot recover from every front being blocked or a broken
origin/CDN configuration.

Installer responses stream through the relay with range and conditional-request
support. Header and idle-read deadlines bound stalled requests without imposing
a total timeout on slow downloads. Closing the relay cancels active requests.
Sparkle and WinSparkle still schedule checks, select versions, verify signatures,
install, and relaunch. Lantern retries only unfinished relay/native setup and
waits for native completion before allowing another manual check.

## Deployment dependencies

Deploy the lantern-cloud `/releases/` route before shipping this client. Legacy
versioned S3 URLs are mapped to that route too. The device never follows an
installer redirect back to S3. Staging alone also permits the existing signed
fixtures from `getlantern/lantern-update-fixtures` on GitHub.

Verify feed query forwarding and installer ranges through each CDN provider.
The CloudFront channel-query issue and Cloudflare Browser Integrity Check rule
are tracked in lantern-cloud's `cmd/autoupdate-server/README.md`; client retries
do not repair those configurations. Complete signed macOS and Windows install
and relaunch tests on a network blocking direct update/S3 access before rollout.

## Verification

```sh
go test -race ./lantern-core/updaterelay
flutter test test/core/updater
make macos-unit-tests
```

The pinned `getlantern/auto_updater` revision includes native delivery fixtures
for Sparkle and WinSparkle in `tests/native_delivery`. Its CI verifies that both
SDKs download through tokenized HTTP loopback URLs, accept signed bytes, and
reject invalid signatures. Installer handoff is intercepted in disposable test
hosts; those fixtures do not replace the signed Lantern rollout test above.

### Signed install and relaunch smoke

Run both `macos-auto-update-smoke.yml` and `windows-auto-update-smoke.yml` with
each `scenario` input:

| Scenario | Conditions |
| --- | --- |
| `baseline` | Check for Updates in Settings, using the staging fixture feed. |
| `core-unavailable` | Hold core initialization pending and let the startup timer check the staging feed. |
| `core-unavailable-direct-blocked` | Hold core initialization pending and block direct update/S3 DNS, using the published beta feed and real fronting. |

The blocked scenario needs the cloud/CDN deployment described above. The staging
hostname has no fronting mapping, so it cannot exercise this path. Each workflow
builds an unpublished, signed profile fixture one build below its selected target.
The test clears the relay's cached fronting configuration. The failure scenarios
also verify that no Lantern bypass proxy is available. They leave the updater,
relay, and native installer unchanged; only the fixture's core initializer is
held pending.

The native scripts accept the update, check the target version and signature,
and require the original process to exit and a new process to show a window.
For the blocked scenario, IPv4 and IPv6 DNS checks confirm the direct hosts
resolve to loopback before launch, at the update offer, and after relaunch.
The diagnostics artifact includes these checks, the source process's handoff,
version checks, logs, and screenshots.

Use the dedicated macOS smoke runner with an interactive login, Accessibility
access, and passwordless `sudo`; Windows uses an elevated hosted runner. These
jobs remove Lantern's installation and test data. Scripts restore only their own
hosts-file entries on exit, with an additional `always()` workflow cleanup step.
An interrupted runner must have those entries removed before it is reused.
