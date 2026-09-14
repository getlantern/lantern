# Installation preflight

The release entry point checks the app's location before loading the main nib.
Debug builds and the system-extension smoke CLI bypass the dialog. Automatic
installation copies into a private staging directory, publishes without replacing
an existing app, then launches a new process. Quarantined apps use Finder.

## Tests

From the repository root, after `flutter pub get`:

```sh
python3 scripts/macos/test_installation_preflight.py
flutter test test/macos/generate_installation_strings_test.dart --no-pub
```

These run in the Swift compile-check workflow. The Python runner compiles the
production installer and committed unit tests in an isolated Swift package, then
compiles the real entry point with startup stubs. It does not start Lantern's VPN.

On a Mac with a logged-in desktop:

```sh
python3 scripts/macos/test_installation_preflight.py --dmg
```

This also tests the native dialogs, cancellation, existing installations,
quarantine handling, and relaunch from a temporary Applications directory. The
DMG case mounts a read-only image and verifies the copied bundle's signature.
Temporary apps are signed ad hoc by default. To test with Developer ID, add
`--sign-identity <certificate-SHA-1>` from `security find-identity -v -p codesigning`.
The fixtures never install into the real `/Applications`. The quarantine fixture
sets the attribute after launch to test the preflight branch; Gatekeeper testing
requires the notarized release check below.

## Translations

`macos_installation_*` entries in `assets/locales/en.po` use the existing Transifex
push/pull workflow. Keep `{appName}`, `{error}`, and `/Applications` unchanged in
translations. The Xcode build phase runs `generate_installation_strings.dart`
to write `AppInstallation.strings` into the app's locale resource directories
before signing. Missing, fuzzy, or incompatible translations fall back to English.
The native dialog uses the macOS language preference before Flutter starts.
Generated tables are build products and should not be committed.

## Gatekeeper release check

The fixtures test copying and process startup; they are not notarized Lantern
releases. Before release, use a Developer ID signed, notarized DMG built from the
branch through the normal macOS release pipeline. Test on a clean Mac or VM with
Gatekeeper enabled, using both the oldest supported macOS and a current version.

1. Download the DMG in Safari so quarantine is present. Validate its ticket with
   `xcrun stapler validate <dmg>` and the mounted app with
   `codesign --verify --deep --strict <app>` and
   `spctl --assess --type execute --verbose=4 <app>`.
2. Launch from the mounted image and from Downloads. Confirm Finder instructions
   appear before Flutter or any system-extension activation. Quit must exit.
3. Follow the instructions using Finder, then open from `/Applications`. Confirm
   Gatekeeper accepts the app and the VPN can activate its system extension.
4. Repeat with an existing installation. Confirm the preflight preserves it and
   directs replacement through Finder.
5. With a locally built, unquarantined release outside `/Applications`, choose
   Move and Relaunch. Confirm the progress dialog stays responsive, the source
   remains, and the new process runs from `/Applications`. Verify its signature
   again. Test an account without write permission to `/Applications` and confirm
   the failure dialog provides Finder instructions.
6. Check a translated macOS language and a right-to-left language after Transifex
   translations arrive. Record the commit, macOS versions, and results.

Do not strip quarantine or disable Gatekeeper to make these checks pass.
