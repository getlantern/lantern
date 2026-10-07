# Windows legacy migration installer

The legacy x86 bridge installs v10 alongside the existing app with:

```text
lantern-installer.exe /LEGACYMIGRATION=1 /LEGACYDIR="C:\Users\Alice\AppData\Roaming\Lantern" /LEGACYSID="S-1-5-21-..." /LEGACYID="<32 lowercase hexadecimal digits>" /NORESTART
```

The bridge verifies the installer signature before launch, keeps its executable
and settings, and waits for the installer to exit. `/VERYSILENT /SUPPRESSMSGBOXES`
is optional.

- `LEGACYDIR` is the actual legacy installation folder. It must be absolute,
  local, accessible, contain `lantern.exe`, and have no junction/symlink components.
- `LEGACYSID` is the original user's SID, even when someone else approves UAC.
- `LEGACYID` is a random identifier saved by the bridge before elevation:
  exactly 32 lowercase hexadecimal digits.

Unknown contract versions and handoff arguments without `/LEGACYMIGRATION=1`
are rejected. Account credentials must never appear in arguments or logs.

## Requirements

Migration requires native x64 Windows 10 1903 (`10.0.18362`) or later. Ordinary
installation retains Inno's `x64compatible` policy, including supported emulation.

Before prerequisites and again before copying files, setup checks that:

- The destination is the default `C:\Program Files\Lantern`. The pinned daemon
  assumes this location, so relocated Program Files layouts are unsupported.
- The destination and `%ProgramData%\Lantern` are absent or empty, accessible,
  and have no reparse-point components. Neither may overlap the legacy folder.
- `LanternSvc` is absent. Service-manager errors block migration.

A global setup mutex prevents concurrent installs. Existing or partially failed
v10 installations require repair/removal before retrying; keep using the legacy
app and preserve account data. Manual installs also refuse to overwrite folders
with legacy settings, pre-v9 executables, or executables of unknown version.

## Installation and recovery

Setup calls `lanternd prepare-legacy-migration` with the original SID, source
folder and migration ID before installing the service. The daemon validates the
user, protects the data directory and saves the enrollment. Later ordinary
upgrades also preserve those restricted permissions while the enrollment exists.

Success requires `lanternd install` to exit successfully and SCM to report
`RUNNING`. On failure, setup attempts to stop/delete its service before reporting
the error. Prerequisite failures require retry or cancellation; required restarts
return control to the bridge without scheduling an elevated RunOnce retry.

| Exit | Bridge action |
| --- | --- |
| `0` | Begin authenticated account handoff; SCM `RUNNING` alone does not prove application readiness. |
| Nonzero, including cancellation, restart or service failure (`1`) | Continue/restart the legacy app and retain its startup entries. |

Setup preserves legacy files, settings, registry entries and shortcuts. It never
runs the legacy uninstaller, creates new shortcuts or launches the new UI. The
destination uninstaller stops only its own UI and retains account data in
`%ProgramData%\Lantern`.
Inno commits files before running service commands, so late failures can leave
new files, registration, data and prerequisites behind. Recovery preserves the
legacy app; it is not a complete rollback of machine changes.

The bridge and Radiance own account/device/settings adoption, readiness checks,
startup switching and explicit recovery. The installer does not perform those
steps. Keep rollout disabled until signed-artifact E2E tests verify the handoff
and recovery.

## Tests

Install the Python dependencies and run the fixture renderer checks:

```sh
python3 -m pip install -r scripts/requirements.txt
python3 -m unittest -v scripts/ci/render_windows_installer_fixture_test.py
```

`.github/workflows/windows-installer-migration-test.yml` builds the production
template with isolated unsigned payloads on an ephemeral Windows runner. It tests
success, rejection, cancellation, prerequisite/enrollment/service/file-copy
failures, and legacy preservation. The harness refuses to mutate ordinary
workstations. These fixtures do not prove real account adoption or replace tests
on unsupported Windows/ARM systems.
