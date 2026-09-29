# Desktop update smoke tests

The macOS and Windows auto-update workflows build a signed beta fixture from the
selected branch, with a build number below the target in the staging appcast.
Sparkle or WinSparkle downloads and installs the target. The smoke checks its
signature and version, waits for the original process to exit, and verifies that
the updated app relaunches with a visible window.

Both workflows accept a `scenario` input:

- `baseline`: start Lantern normally and check for updates through the app menu.
- `core-unavailable`: hold core initialization indefinitely and let the normal
  startup update check run. The test verifies that core is still unavailable and
  no VPN bypass proxy is listening when the native updater offers an update.

Dispatch `macos-auto-update-smoke.yml` or `windows-auto-update-smoke.yml` with the
branch to test and either scenario. macOS uses the dedicated smoke runner;
Windows uses a disposable hosted runner. The scripts replace the installed app
and remove its test data, so run them only through these guarded CI workflows.

The diagnostics include the resolved target, Flutter log, native handoff, process
IDs, signatures, versions, and screenshots. These scenarios use the staging feed
and its signed fixtures. They do not test blocked endpoints or domain fronting.
