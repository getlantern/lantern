# macOS CI runners

Release builds, staging test builds, and Swift compile/unit checks use GitHub-hosted
macOS runners. The reusable `build-macos.yml` workflow defaults to `macos-15`;
release builds no longer offer an EC2 runner option. Signed auto-update fixtures
also build on the hosted runner.

Stateful smoke tests use a separate runner labeled `lantern-macos-smoke`. Enable
them by setting the repository Actions variable `MACOS_STATEFUL_SMOKE_ENABLED`
to `true`; leaving it unset or setting it to `false` disables them.
Requests for disabled smoke tests fail on an Ubuntu runner with an explanation
and job summary, instead of waiting for a missing macOS runner or reporting a
successful test.

## Coverage while the dedicated runner is disabled

The macOS suites in **App Smoke Tests** are unavailable: VPN connect/disconnect,
VPN lifecycle recovery, auth, and payment. The separate **macOS auto-update
smoke** workflow is also unavailable, including its installation, Sparkle UI,
and relaunch checks. Hosted builds and compile/unit checks continue, but do not
replace this runtime coverage. Exercise the affected behavior manually on a
configured test Mac before relying on it for a release.

The nightly App Smoke Tests sweep already excludes these macOS suites. An
explicit `platforms=all, tests=auto-update` request still runs Windows auto-update
tests, and reports the missing macOS coverage as a failure.

## Validate hosted builds without publishing

Dispatch **Build and Release** from a reviewed non-default branch with
`build_type=nightly` and `platforms=macos`. The workflow marks this as a test run,
builds and notarizes the macOS artifacts, and skips release/S3 publication and
success notifications. Inspect the uploaded app and DMG, signing/notarization
results, and Intel/ARM64 binary slices. A dispatch from the default branch is
not a test run and can publish nightly artifacts.

## Enable a replacement Mac mini

1. Configure a dedicated CI account and register the replacement GitHub Actions
   runner with the `lantern-macos-smoke` label. Only the intended replacement
   should carry that label when tests are enabled.
2. Install the build prerequisites and configure the runner in a logged-in desktop
   session. Approve Lantern's signed system extension and VPN configuration,
   including any required reboot. Grant Accessibility access to the active
   `Runner.Listener` for the [native updater driver](desktop-updates.md).
3. Verify that the CI account can replace `/Applications/Lantern.app`, clear
   `/Users/Shared/Lantern`, and use passwordless `sudo` for the update scenario's
   hosts-file cleanup. These tests replace the installed app, delete its data,
   and change VPN/network state; use the dedicated test account and machine.
4. Confirm the replacement runner is online, then set the repository Actions
   variable `MACOS_STATEFUL_SMOKE_ENABLED` to `true`.
5. Dispatch App Smoke Tests with `platforms=macos` for VPN smoke, VPN lifecycle,
   auth, and payment. Dispatch macOS auto-update smoke for all three scenarios.
   Check the diagnostics and installation/relaunch results. Set the variable
   back to `false` if the runner is unavailable or these prerequisites fail.

Keep code-signing, provisioning, notarization, and Sparkle secrets in GitHub
Actions; removing the EC2 runner does not remove the hosted builds' need for
them. The reusable `runner_label` input remains available for the smoke runner.
