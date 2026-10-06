# Windows migration verification probe

Build against the pinned Radiance module:

```sh
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -tags with_clash_api -o migration-probe.exe ./scripts/migration-e2e/probe
go test -race ./scripts/migration-e2e/probe
```

Run as the original desktop user, after the harness verifies that the installed
service uses `--environment staging`. The fixture's staging label alone does not
prove the service's account-server configuration.

```powershell
.\migration-probe.exe --expected C:\private\expected.json --mode verify --timeout 90s
.\migration-probe.exe --expected C:\private\expected.json --mode connect --probe-url https://controlled.example/connectivity --timeout 90s
.\migration-probe.exe --expected C:\private\expected.json --mode disconnect --timeout 90s
```

The private expected JSON requires every field below. Keep credentials in that
local file; never place them in command arguments, environment variables, or CI
artifacts. The account ID is a positive decimal string to preserve all int64 bits.

```json
{
  "schema_version": 1,
  "account_environment": "staging",
  "user_id": "123",
  "token": "<private staging account token>",
  "device_id": "<original runtime device ID>",
  "locale": "en",
  "auto_report": false,
  "proxy_all": false,
  "auto_launch": true,
  "user_level": "pro"
}
```

All modes use ordinary Radiance IPC to compare cached and freshly authenticated
account data, exact account tokens, runtime device identity, Pro/free status, and
settings. The startup preference is the adopted `legacy_auto_launch` setting;
the harness must verify the original user's actual Run entry separately.
`verify` does not change VPN connection state. `connect` waits for Connected,
requires a successful HTTPS response without redirects, and rechecks Connected.
This proves connectivity while the VPN reports connected, not that a particular
request traversed the tunnel. `disconnect` waits for Disconnected. If a mode
fails, it leaves further cleanup to the harness.

Stdout contains one JSON object and exit code 0 means all mode checks passed.
Output includes only fixed phase/error codes, booleans, and `identity_sha256`,
computed as SHA256 of UTF-8 `decimal user ID + "\n" + device ID`. Tokens, raw IDs,
device IDs, email addresses, fixture paths, and raw IPC/network errors are never
printed. Timeouts are bounded to 15 minutes; unsupported platforms fail closed.
