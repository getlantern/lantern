# Desktop updates

Sparkle schedules recurring checks on macOS. On Windows, Lantern schedules a
check an hour after the previous update cycle finishes. WinSparkle's periodic
worker can stop after a failed request, so its timer stays disabled. Failed
Windows checks retry after 1, 5, and 15 minutes, then hourly until a check succeeds.
Resuming the app or reconnecting can bring a pending retry forward.

Manual and automatic Windows checks share the same guard. The guard stays held
while the native prompt or download is active and is released by the completion
callback. Sparkle and WinSparkle handle signatures, installation, and relaunch.

## Smoke tests

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

The macOS workflow first tests the native UI driver against a small fixture
window. It uses the public Accessibility API to press Sparkle's install buttons
and detect the relaunched window. The active `Runner.Listener` needs Accessibility
approval in the runner's logged-in desktop session; System Events Automation
approval is not required.

The diagnostics include the resolved target, Flutter log, native handoff, process
IDs, signatures, versions, and screenshots. These scenarios use the staging feed
and its signed fixtures. They do not test blocked endpoints or domain fronting.
