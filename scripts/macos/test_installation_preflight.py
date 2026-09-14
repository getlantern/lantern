#!/usr/bin/env python3
"""Run isolated installation tests; --ui also exercises AppKit and Launch Services."""

import argparse
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "macos/Runner/AppInstallation.swift"
FIXTURES = Path(__file__).resolve().parent / "fixtures"


def run(*args, env=None, expected_code=0):
    result = subprocess.run(
        [str(arg) for arg in args], cwd=ROOT, env=env,
        capture_output=True, text=True, timeout=180,
    )
    if result.returncode != expected_code:
        raise AssertionError(f"{args[0]} exited {result.returncode}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def unit_tests(work):
    package = work / "package"
    for path in ("Sources/Lantern", "Tests/LanternTests"):
        (package / path).mkdir(parents=True)
    shutil.copy2(SOURCE, package / "Sources/Lantern/AppInstallation.swift")
    shutil.copy2(ROOT / "macos/RunnerTests/AppInstallationTests.swift",
                 package / "Tests/LanternTests/AppInstallationTests.swift")
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "InstallationTests", platforms: [.macOS(.v10_15)], targets: [
  .target(name: "Lantern"), .testTarget(name: "LanternTests", dependencies: ["Lantern"])
])
''')
    env = {**os.environ, "CLANG_MODULE_CACHE_PATH": str(work / "module-cache"),
           "SWIFTPM_MODULECACHE_OVERRIDE": str(work / "module-cache")}
    print(run("swift", "test", "--package-path", package, "--scratch-path", work / "build",
              "--cache-path", work / "cache", "--config-path", work / "config",
              "--security-path", work / "security", "--disable-sandbox", env=env))


def startup_tests(work):
    for configuration, flags in (("release", []), ("debug", ["-D", "DEBUG"])):
        binary = work / configuration
        run("swiftc", "-swift-version", "5", "-module-cache-path", work / "module-cache",
            *flags, ROOT / "macos/Runner/main.swift", FIXTURES / "StartupStubs.swift", "-o", binary)
        for allowed in (False, True):
            env = {**os.environ, "ALLOW_STARTUP": "1" if allowed else "0"}
            expected = [] if configuration == "debug" else ["preflight"]
            if configuration == "debug" or allowed:
                expected.append("application-bootstrap")
            assert run(binary, env=env).splitlines() == expected
        assert run(binary, "--smoke").splitlines() == ["filesystem", "extension-manager", "smoke"]
        assert run(binary, "--invalid", expected_code=64).strip() == "invalid"
    print("PASS: debug/release startup, blocked/allowed launch, CLI bypass and parse errors")


def native_test(work, binary, action, identity, disk_image=False):
    directory = work / ("disk-image" if disk_image else action)
    source = directory / "Downloads/Lantern Fixture.app"
    applications = directory / "Applications"
    marker = directory / "launched.txt"
    executable = source / "Contents/MacOS/Fixture"
    executable.parent.mkdir(parents=True)
    applications.mkdir()
    shutil.copy2(binary, executable)
    info = {
        "CFBundleExecutable": "Fixture", "CFBundleName": "Lantern Preflight Fixture",
        "CFBundleIdentifier": "org.getlantern.installation-fixture." + directory.name,
        "CFBundlePackageType": "APPL", "NSPrincipalClass": "NSApplication",
        "CFBundleDevelopmentRegion": "en", "FixtureApplications": str(applications),
        "FixtureMarker": str(marker), "FixtureAction": action,
    }
    with (source / "Contents/Info.plist").open("wb") as output:
        plistlib.dump(info, output)
    run("dart", "scripts/macos/generate_installation_strings.dart", ROOT / "assets/locales",
        source / "Contents/Resources")
    run("codesign", "--force", "--options", "runtime", "--sign", identity, source)
    destination = applications / source.name
    if action == "existing":
        destination.mkdir()
        (destination / "keep").write_text("existing installation")
    mount = directory / "mounted"
    if disk_image:
        image = directory / "fixture.dmg"
        run("hdiutil", "create", "-srcfolder", source.parent, "-format", "UDZO", image)
        mount.mkdir()
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, image)
        source = mount / source.name
        executable = source / "Contents/MacOS/Fixture"
    try:
        run(executable, *(["-AppleLanguages", "(fr)"] if action == "cancel" else []))
        assert source.exists(), "source was removed"
        assert not list(applications.glob(".lantern-install-*")), "staging directory was left behind"
        if action == "install":
            deadline = time.monotonic() + 10
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(0.05)
            assert marker.exists(), "installed process did not launch"
            assert Path(marker.read_text()).resolve() == destination.resolve()
            run("codesign", "--verify", "--deep", "--strict", destination)
        else:
            assert not marker.exists(), "blocked process continued startup"
            if action == "existing":
                assert (destination / "keep").read_text() == "existing installation"
            else:
                assert not destination.exists()
            if action == "quarantine":
                assert run("xattr", "-p", "com.apple.quarantine", source).strip() == "0083;00000000;Fixture;"
    finally:
        if disk_image:
            run("hdiutil", "detach", mount)
    print(f"PASS: native {action}" + (" from a read-only DMG" if disk_image else ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ui", action="store_true", help="requires a logged-in macOS desktop")
    parser.add_argument("--dmg", action="store_true", help="also test copying from a read-only DMG (implies --ui)")
    parser.add_argument("--sign-identity", default="-", help="codesign identity for UI fixtures; defaults to ad hoc")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="lantern-preflight-") as temporary:
        work = Path(temporary).resolve()
        print("Running installation unit tests…", flush=True)
        unit_tests(work)
        startup_tests(work)
        if args.ui or args.dmg:
            binary = work / "NativeFixture"
            run("swiftc", "-swift-version", "5", "-module-cache-path", work / "module-cache",
                SOURCE, FIXTURES / "NativePreflight/main.swift", "-o", binary)
            for action in ("cancel", "existing", "quarantine", "install"):
                native_test(work, binary, action, args.sign_identity)
            if args.dmg:
                native_test(work, binary, "install", args.sign_identity, disk_image=True)


if __name__ == "__main__":
    main()
