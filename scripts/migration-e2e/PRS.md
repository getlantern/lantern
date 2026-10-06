# Recommended migration PRs

Open four feature PRs and three E2E companion PRs. Existing installer and identity/startup work shares a branch in each repository; keep that coherent change together rather than inventing additional PRs from the same tip. No PRs were opened by this task.

## Feature PRs

### 1. lantern-cloud — `Define gated Windows x86 bridge migration routing`

Head: `atavism/issue-3959`. Base: `main`.

Accept native Windows OS architecture separately from app architecture and require an explicit safe-installer capability. Route eligible unknown legacy clients to the pinned x86 bridge, and confirmed compatible bridge clients to the pinned v10 installer. Preserve legacy behavior for unsupported or unknown destinations. Keep all migration pins and rollout gates disabled by default.

Validation: compatibility/routing tables, signed response contract and disabled-gate tests. No production activation.

### 2. radiance — `Adopt legacy Windows identity before switching VPN ownership`

Head: `atavism/issue-3959`. Base: `main`.

Enroll the original Windows user through a protected installer handoff and authenticate that user on the dedicated migration pipe. Verify legacy account credentials with the account service, durably adopt account/device/settings, and issue readiness only after live settings, account data and ordinary IPC agree. Support idempotent replay and authenticated disconnect for rollback.

Validation: adoption/authentication, persistence/crash/replay, readiness and rollback tests, including native Windows coverage. This is the dependency for the destination installer integration.

### 3. lantern — `Preserve legacy Windows installations during v10 migration`

Head: `atavism/issue-3959`. Base: `main`. Depends on the Radiance feature PR.

Validate Windows version, native architecture, original identity and safe separate installation paths before changes. Preserve the legacy executable, settings and startup state; enroll the original user before installing the new service. Integrate the Radiance migration dependency and keep cancellation, prerequisite, copy and service failures recoverable.

Validation: native Windows installer matrix for success, cancellation, existing state, unsafe paths and installation failures, plus core integration checks. Installer exit zero alone does not claim migration completion.

### 4. lantern-desktop — `Add the x86 migration bridge with verified installer and startup handoff`

Head: `atavism/issue-3959`. Base: the Windows `lantern-7.9.5` source/release maintenance base, **not current main**. GitHub PR bases must be branches: use an existing branch at that source or create a maintenance base branch at `1145e4ca7a7d1d5bfb7b4cd9cdb719a7aaea202e` before opening. Do not rebase this compatibility release onto modern desktop main.

Build on the last compatible Windows x86 release with frozen dependencies. Report native OS architecture/version independently, verify and launch v10 installers separately from binary replacement, and transfer the coherent runtime account/settings through the authenticated migration channel. Journal installation and startup transitions, prevent repeated elevation, preserve recovery, and switch startup only after the new service is ready. Keep the production installer-handoff capability disabled pending rollout proof.

Validation: portable contract tests, pinned Go 1.22.4 Windows386 builds and native identity/startup/recovery tests. The release tooling validates source/toolchain/dependency provenance.

## E2E companion PRs

### 5. lantern-cloud — `Add isolated staging configuration and contract checks for Windows migration`

Head: `atavism/issue-3959-e2e`. Base initially: `atavism/issue-3959`; retarget `main` after PR 1 merges (rebase/cherry-pick the E2E commits if it is squash-merged).

Wire explicit bridge/installer pins into the staging updater while rejecting production/project/catalog drift and leaving defaults disabled. Exercise both signed hops, constrained Unleash cohorts, nonce verification, and unsupported/missing-artifact cases. Document catalog readiness, shared staging isolation and the released-binary account-endpoint limitation.

Validation: full updater Go suite, isolated Terraform variable tests and repository lint. No deployment or flag activation.

### 6. lantern-desktop — `Build isolated legacy migration fixtures and runtime evidence`

Head: `atavism/issue-3959-e2e`. Base initially: `atavism/issue-3959`; retain the same maintenance line after PR 4 merges.

Add manual artifact-only builds for an exact-source 7.9.5 seed with a staging account-host override and a staging-only migration bridge. Preserve the original updater and RSA trust, record a credential-free snapshot from live Settings, and validate full sticky configuration with the frozen legacy decoder before launching the seed. Reject staging-only tags/overrides in normal release validation.

Validation: pinned-toolchain portable tests, Windows386 helper/updater compilation where CGO is not required, provenance and release-validator tests. Fixtures remain unsigned until the approved signing process; the full native CGO helper/app build is a dispatched workflow check. A rebuilt fixture cannot claim original released-binary or production activation proof.

### 7. lantern — `Exercise the Windows legacy-to-v10 migration chain in staging`

Head: `atavism/issue-3959-e2e`. Base initially: `atavism/issue-3959`; retarget `main` after PR 3 merges (handle squash merges as above). Depends on PRs 5 and 6 for a live run.

Add a manually dispatched disposable-VM harness for the real seed → bridge → signed installer → authenticated service → startup/reboot chain. Pin source/artifact digests and signer identities, validate staging-only build/configuration, compare live account/device/settings and Pro status through real IPC, and cover cancellation and installer rejection with preserved legacy state. Add a guarded staging destination build, safe hosted contract checks and allowlisted diagnostics. A successful initial checkpoint remains pending until a real reboot pass.

Validation: Python manifest/catalog/installer-guard tests, PowerShell parser and safe helper tests, portable probe race/vet checks and Windows probe cross-compilation. **The live staging VM chain has not been run by this local-only task.** Publication, fixture provisioning, signing, staging configuration and native execution remain operational prerequisites documented in README.md.

## Activation follows evidence

Activation is a later `lantern-cloud` configuration change or separate PR after the original released-binary proof gap and required native staging runs are resolved. Suggested title if code is needed: `Enable the staged Windows bridge migration rollout`. Scope: narrowly constrained cohort, independently gated hops, measured migration completion/failure and rollback/hold controls. Do not combine activation with the seven PRs above.
