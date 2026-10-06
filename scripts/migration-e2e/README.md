# Windows legacy migration staging E2E

This exercises **7.9.5 x86 → bridge x86 → v10 installer → authenticated Radiance adoption → startup → reboot**, using the real updater, installer, service and IPC. It does not deploy, publish, enable flags, create accounts or provision machines. All production rollout gates remain disabled.

## What a pass means

The executable lane is `rebuilt-staging`. The seed is rebuilt from the exact Windows `lantern-7.9.5` source (`1145e4ca7a7d1d5bfb7b4cd9cdb719a7aaea202e`) with the account host linker override `github.com/getlantern/flashlight/v7/common.ProAPIHost=api-staging.getiantem.org`. The updater implementation and embedded RSA public key remain unchanged. Do **not** use `StagingMode`/`STAGING=1`: that mode substitutes a shared hardcoded account.

The original released 7.9.5 binary hardcodes the production account API. Its supported configuration changes the updater endpoint/CA, not that account API. Consequently an isolated full account-migration test with the original release is **blocked pending a reviewed endpoint/account strategy**. This harness rejects a `released-7.9.5` manifest and always records `production_activation_ready: false`. Neither a rebuilt pass nor synthetic HTTP requests satisfy that release prerequisite.

The real clients must accept signatures from the staging updater using the RSA key compiled into 7.9.5. Replacing that public key, disabling TLS verification, hosts-file/TLS interception, or using `mockupdate` would change the property being tested and is not supported. If staging's signing key is incompatible, stop and resolve the trust arrangement separately.

## Companion branches and checks

- `lantern-cloud/atavism/issue-3959-e2e`: staging pins and signed-handler/cohort tests, stacked on the migration routing contract. Its README has the exact Terraform/Unleash configuration.
- `lantern-desktop/atavism/issue-3959-e2e`: artifact-only seed/bridge builds, `migratione2e` compile-time staging guard, a redacted live Settings snapshot, and the frozen legacy global-config checker.
- This branch: guarded staging destination build, immutable bundle checks, original-user VM orchestration, and the real IPC verification probe. Radiance production behavior comes from the existing migration dependency; there is no E2E service endpoint.

Safe hosted CI runs Python tests, parses PowerShell and tests/builds the Windows probe in `windows-migration-e2e-checks.yml`. The existing `windows-installer-migration-test.yml` remains the automated native installer failure matrix. The new live-chain workflow is manual and uses a dedicated interactive disposable VM.

## Build and prepare the catalog

1. Review and merge/stack the three E2E companions on their migration branches. Build the desktop fixture workflow at the reviewed commit. It returns **unsigned** seed/bridge artifacts and provenance, plus `global-config-check.exe`; these are not release-ready assets.
2. Pass the seed and bridge through the approved Authenticode signing process. Preserve their original Go build metadata and retain the signing run/provenance. Recompute all hashes **after** signing. Do not edit the unsigned descriptor to imply its earlier digest was signed. The normal desktop production release validator intentionally rejects these staging builds.
3. Run `build-windows-migration-e2e.yml` with an unused stable-format `10.x.y` version reserved only in `getlantern/lantern-update-fixtures`. It requires explicitly configured `STAGING_APP_ENV`, optional `STAGING_JOIN_SERVER_CONFIG_URLS`, and the existing signing secret/policy. It builds a signed staging-backed destination artifact only. Both Flutter and the installed service use staging; the service command is compiled into the installer. Rename the resulting installer locally to `lantern-installer.exe` for the legacy catalog.
4. Download the probe from the harness-check workflow at the reviewed Lantern commit (or build it with `CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -tags with_clash_api -o migration-probe.exe ./scripts/migration-e2e/probe`). Record its SHA256. Download the companion config checker at the reviewed desktop commit.
5. Prepare a **complete valid legacy global config** as JSON (JSON is accepted by the old YAML decoder), with `updateserverurl: "https://update.staging.iantem.io"` and the reviewed staging `autoupdateca`. Preserve the required trusted CAs/fronting/provider configuration. A two-field stub is invalid: the old app would fall back to its embedded config. The harness checks this file with the frozen legacy decoder and validators before launching the seed. Run the VM on an isolated network with production account/update endpoints denied as defense in depth; configure trusted staging/fronting connectivity deliberately.
6. Create `manifest.json` in a bundle containing the signed seed, signed bridge, signed installer, probe, checker and global JSON. Use the schema below. Review the source commits, signed build provenance, signer thumbprints, endpoint and post-signing hashes. The manifest hash is the external approval/pinning input; a sidecar supplied alongside untrusted bytes is not sufficient review. The harness reads the seed/bridge's actual Go build information and requires their exact source, toolchain, tags and staging overrides before execution.
7. Assemble catalog files without publishing:

   ```sh
   python scripts/migration-e2e/catalog.py /absolute/bundle \
     --manifest-sha256 APPROVED_SHA256 --output /absolute/new-catalog-output
   ```

   The bridge is `v7.x.y/update_windows_386_7.x.y.bz2`, compressed **after** signing; the destination is `v10.x.y/lantern-installer.exe`. The server hashes the decompressed bridge and raw installer, then signs the response/assets with its configured RSA key. Do not add production `.update.json` sidecars or appcasts. Do not publish to the public Lantern release repositories. An authorized operator publishes these two reserved stable-format fixture releases separately; this command and all new workflows do not publish.
8. Reserve an exclusive staging window: the catalog, updater pins and Unleash flags are shared. Set the companion's explicit `STAGING_WINDOWS_BRIDGE_VERSION` / `STAGING_WINDOWS_INSTALLER_VERSION` and constrain **both** migration gates plus the general allow gate to the dedicated VM's egress IP and exact source/target versions. Keep production pins empty/flags off. Use the cloud repository's deployment procedure; allow catalog refresh (normally up to 30 minutes). The harness probes both expected byte digests and unsupported/unknown routes before mutation and again after migration. Its synthetic preflight does not claim RSA verification; the actual two clients provide that evidence.

Manifest structure (replace all example hashes, versions, commits, thumbprints and URL):

```json
{
  "schema_version": 1,
  "run_id": "0123456789abcdef0123456789abcdef",
  "lane": "rebuilt-staging",
  "scenario": "success",
  "endpoint": "https://update.staging.iantem.io/update/lantern",
  "catalog": "getlantern/lantern-update-fixtures",
  "account_environment": "staging",
  "production_activation_ready": false,
  "bridge_version": "7.9.6",
  "installer_version": "10.99.1",
  "probe_url": "https://CONTROLLED-STAGING-HOST/health",
  "source_commits": {
    "seed": "1145e4ca7a7d1d5bfb7b4cd9cdb719a7aaea202e",
    "lantern": "40_LOWERCASE_HEX",
    "lantern-desktop": "40_LOWERCASE_HEX",
    "radiance": "40_LOWERCASE_HEX",
    "lantern-cloud": "40_LOWERCASE_HEX"
  },
  "artifacts": {
    "seed": {"file": "seed.exe", "sha256": "64_LOWERCASE_HEX", "signer_thumbprint": "40_HEX"},
    "bridge": {"file": "bridge.exe", "sha256": "64_LOWERCASE_HEX", "signer_thumbprint": "40_HEX"},
    "installer": {"file": "lantern-installer.exe", "sha256": "64_LOWERCASE_HEX", "signer_thumbprint": "40_HEX"},
    "probe": {"file": "migration-probe.exe", "sha256": "64_LOWERCASE_HEX"},
    "global_checker": {"file": "global-config-check.exe", "sha256": "64_LOWERCASE_HEX"},
    "global_config": {"file": "global.json", "sha256": "64_LOWERCASE_HEX"}
  }
}
```

## Provision one disposable VM per scenario

Use native x64 Windows 10 1903+ or Windows 11, with Python 3.11+, PowerShell 7.2+, Go (for inspecting build metadata), required app prerequisites, and an interactive **standard user** session. A separate administrator approves the real UAC prompt. The GitHub runner must run interactively as that original user; a Session 0 service runner or elevated administrator runner is rejected. Register only this leased VM under `lantern-migration-e2e`, and configure the protected `staging-migration-e2e` environment. Do not run this on a personal workstation.

The administrator/provider creates `C:\ProgramData\LanternMigrationE2E\lease.json`, with administrator/SYSTEM ownership, write access restricted to those principals (including its directory), and standard-user read access:

```json
{"run_id":"SAME_32_HEX_ID","machine":"EXACT_COMPUTERNAME","original_sid":"S-1-5-21-...","expires_utc":"FUTURE_UTC_ISO8601"}
```

Copy the reviewed bundle to `C:\MigrationE2E\bundle`. Place a dedicated **staging** account fixture at `%LOCALAPPDATA%\LanternMigrationFixture\expected.json`, readable only by the original user/SYSTEM/administrators. Use one disposable account/device per run, including a Pro account for the Pro scenario. Never place it in the repository, manifest, CLI arguments, environment, upload artifacts or screenshots. Schema:

```json
{
  "schema_version": 1, "account_environment": "staging",
  "user_id": "DECIMAL_INT64_AS_STRING", "token": "PRIVATE_TOKEN", "device_id": "PRIVATE_DEVICE_ID",
  "locale": "en-US", "auto_report": false, "proxy_all": true, "auto_launch": true, "user_level": "pro"
}
```

There must be no Lantern process, installation, service, enrollment, startup entry, old device-ID registry key, or `%APPDATA%\Lantern` directory. The runner refuses existing state; it never wipes it. It seeds the historical `HKCU\Sofware\\Lantern` device ID key (the typo is real), the default config path and a private source folder with spaces. The legacy runtime snapshot checks the actual registry-derived identity; YAML `deviceID` is not trusted. Ordinary source directories allow the approving administrator to read/traverse; account data stays private.

## Execute and reboot

Dispatch `windows-migration-e2e.yml`, or run the same command as the standard user:

```powershell
./scripts/migration-e2e/run.ps1 -Bundle C:\MigrationE2E\bundle `
  -Expected "$env:LOCALAPPDATA\LanternMigrationFixture\expected.json" `
  -ManifestSHA256 APPROVED_SHA256 -Phase Run
```

The script launches the seed and waits for **the updater** to replace its EXE with the approved bridge digest. It then models a user restart; it never copies the bridge into place. It checks the bridge's live account hash/preferences before allowing success evidence. The script does not automate the secure UAC desktop: approve using the other administrator and complete the real installer when prompted.

A successful initial run returns **exit 2 / `awaiting_reboot`**, saves private run state, and is **not a completed E2E pass**. Reboot the actual VM, log in as the same user, resume the interactive runner if needed, and rerun with `-Phase AfterReboot`. It requires a different boot timestamp, the same SID/bundle/identity/journal, a running staging service, correct startup behavior, fresh server-verified account data and working VPN connect/disconnect. Only this phase reports `rebuilt_staging_chain_passed`. Workflow checkpoint success while awaiting reboot only means the checkpoint was reached; inspect `ok` and `code` in JSON.

The HTTPS probe proves connectivity while the service reports Connected; it does not by itself prove packet routing or public-IP change. The configured URL must be a controlled HTTPS endpoint with no credentials/query/redirects.

## Failure cases and coverage boundaries

Run each case on a fresh leased VM and staging account, with a new run ID and manifest hash:

| Case | Driver and expected evidence |
| --- | --- |
| Free and Pro, non-default settings | `success`, both Run and AfterReboot. Compare exact ID/token/device/Pro status/preferences using real IPC and fresh account API. Repeat with auto-launch enabled and disabled. |
| Original standard user + different approving admin | Same successful chain; protected source traversal and authenticated original SID are required. |
| User cancels elevation | `scenario: cancel`; decline the actual UAC prompt. Require a failed/cancelled durable attempt, no service/startup switch, preserved legacy credentials/executable, and unchanged attempt after restart. |
| Installer preflight failure | `scenario: installer-failure`; when prompted, the VM administrator creates `C:\Program Files\Lantern\migration-e2e-sentinel.txt` containing the run ID. Approve UAC. The real installer must reject the occupied destination; the harness requires the same recovery evidence. |
| Native x86/ARM64/unknown routing | Synthetic staging HTTP preflight denies installer routes for these reports. This is **routing coverage**, not hardware emulation. A real unsupported-machine matrix remains separate. |
| Bad nonce/signature, missing catalog assets, wrong cohort | Cloud signed-handler tests plus desktop bridge validation tests. These are contract/unit tests, not a remotely fault-injected full-chain pass. |
| Prerequisite/copy/service failures, cancellation, unsafe paths | Existing native installer smoke workflow. |
| Auth rejection, crash/replay, authenticated rollback | Existing Radiance/bridge tests and native migration tests. A mid-handoff VM crash/rollback campaign still needs separate orchestration; this harness does not claim it. |

Diagnostics are allowlisted booleans/hashes/fixed codes only, under the private run directory's `diagnostics` folder. The workflow uploads only the requested phase JSON; it does not upload raw settings, tokens, account IDs, device IDs, service data, journals, logs, dumps or screenshots. Inspect sensitive failure state inside the disposable VM if needed.

After recording evidence, disable the staging migration cohort, clear the staged pins using the cloud deployment procedure, release the shared test window, revoke the fixture account/token, and destroy the VM. Do not reuse its snapshot or manually delete migration journals to retry. Production activation is separate work with its own released-binary proof and rollout decision.
