# Desktop update delivery

Lantern starts the update relay in the app process before configuring Sparkle or
WinSparkle. It does not require the VPN service or daemon IPC. Both the appcast
and its installer URLs point to a random, per-process loopback endpoint. Only
artifacts registered by the configured Lantern feed can be requested.

The relay tries HTTPS directly, then uses Radiance's independent domain-fronting
client on connection failures, 403s, or server errors. That client starts from
embedded configuration and keeps its own cache under `update-transport` in the
user's application support directory. It uses the bypass dialer while the VPN is
active, and ordinary sockets when the VPN is down.

Installer responses stream through the relay with range and conditional-request
support. Header and idle-read deadlines bound stalled requests without imposing
a total timeout on slow downloads. Closing the relay cancels active requests.
The native updater still selects versions, verifies signatures, installs, and
relaunches. Lantern owns the hourly timer and waits for native completion before
retrying; cancellation is not a failed check.

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
