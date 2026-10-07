#!/usr/bin/env python3
"""Compile the installer and execute its VC runtime checks with registry fixtures.

Requires Inno Setup 6.7.1 on Windows. --generate-only writes the sources for
inspection on other hosts. The full installer is compiled but never run; only
the isolated fixture harness runs, and it exits before installation begins.
"""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "windows/packaging/exe/inno_setup.iss"
HARNESS = Path(__file__).with_name("windows_installer_test.iss")


def generate_staging_fixture(output):
    directory = output / "staging fixture"
    toolchain = directory / "selected toolchain"
    user_props = directory / "user props"
    toolchain.mkdir(parents=True, exist_ok=True)
    user_props.mkdir(exist_ok=True)
    (toolchain / "vc_redist.x64.exe").write_bytes(b"selected toolchain runtime\n")

    project = ET.Element("Project", xmlns="http://schemas.microsoft.com/developer/msbuild/2003")
    properties = ET.SubElement(project, "PropertyGroup")
    for name, value in {
        "VCToolsRedistDir": str(toolchain) + os.sep,
        "OutDir": "$(MSBuildProjectDirectory)\\build $(Configuration)\\",
        "UserRootDir": str(user_props),
        "Platform": "x64",
    }.items():
        ET.SubElement(properties, name).text = value
    ET.SubElement(project, "Import", Project=str(ROOT / "windows/runner/stage_vcredist.props"))
    build = ET.SubElement(project, "Target", Name="Build")
    ET.SubElement(build, "Error", Condition="'$(FixtureUserProperty)' != 'preserved'",
                  Text="The normal platform user.props import was lost")
    ET.indent(project)
    ET.ElementTree(project).write(directory / "staging.proj", encoding="utf-8", xml_declaration=True)
    (user_props / "Microsoft.Cpp.x64.user.props").write_text(
        '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
        '<PropertyGroup><FixtureUserProperty>preserved</FixtureUserProperty>'
        '</PropertyGroup></Project>', encoding="utf-8",
    )


def test_staging(output):
    msbuild = shutil.which("MSBuild.exe")
    if not msbuild:
        vswhere = Path(os.environ["ProgramFiles(x86)"]) / "Microsoft Visual Studio/Installer/vswhere.exe"
        installation = subprocess.check_output(
            [str(vswhere), "-latest", "-products", "*", "-requires", "Microsoft.Component.MSBuild",
             "-property", "installationPath"], text=True,
        ).strip()
        if not installation:
            raise FileNotFoundError("Visual Studio with MSBuild was not found")
        msbuild = str(Path(installation) / "MSBuild/Current/Bin/MSBuild.exe")

    directory = output / "staging fixture"
    source = directory / "selected toolchain/vc_redist.x64.exe"

    def build(configuration, should_succeed=True):
        completed = subprocess.run(
            [msbuild, str(directory / "staging.proj"), "/nologo", "/v:minimal", "/t:Build",
             f"/p:Configuration={configuration}"], capture_output=True, text=True, timeout=60,
        )
        if (completed.returncode == 0) != should_succeed:
            raise AssertionError(completed.stdout + completed.stderr)

    for configuration in ("Release", "Profile"):
        destination = directory / f"build {configuration}/installer-dependencies/VC_redist.x64.exe"
        destination.unlink(missing_ok=True)
        build(configuration)
        assert destination.read_bytes() == source.read_bytes(), configuration + " staged wrong payload"
        source.write_bytes(source.read_bytes() + b"toolchain update\n")
        build(configuration)
        assert destination.read_bytes() == source.read_bytes(), configuration + " kept stale payload"
        print(f"PASS: {configuration} stages selected toolchain and refreshes incremental builds")

    source.unlink()
    build("Debug")
    assert not (directory / "build Debug/installer-dependencies/VC_redist.x64.exe").exists()
    print("PASS: Debug needs no redistributable")
    build("Release", should_succeed=False)
    print("PASS: Release rejects missing selected-toolchain redistributable")


def render_compile_fixture(source, payload):
    # Render only the template's English locale and desktop-icon flag. Fail on
    # new template syntax instead of silently compiling a different installer.
    def english_loop(match):
        return re.sub(
            r"{% if locale == '([^']+)' %}(.*?){% endif %}",
            lambda condition: condition[2] if condition[1] == "en" else "",
            match[1],
            flags=re.DOTALL,
        )

    source = re.sub(
        r"{% for locale in LOCALES %}(.*?){% endfor %}",
        english_loop,
        source,
        flags=re.DOTALL,
    )
    source = source.replace(
        "{% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}",
        "checkedonce",
    )
    values = {
        "SOURCE_DIR": str(payload),
        "APP_ID": "LanternInstallerCompileFixture",
        "APP_VERSION": "0.0.0",
        "DISPLAY_NAME": "Lantern Installer Compile Fixture",
        "PUBLISHER_NAME": "Lantern",
        "PUBLISHER_URL": "https://getlantern.org",
        "OUTPUT_BASE_FILENAME": "compile-fixture",
        "EXECUTABLE_NAME": "lantern.exe",
    }
    source = re.sub(r"{{(\w+)}}", lambda match: values[match[1]], source)
    if "{{" in source or "{%" in source:
        raise ValueError("Unrendered installer template syntax")
    return source


def generate(output):
    source = TEMPLATE.read_text(encoding="utf-8")
    for directive in ("ArchitecturesAllowed", "ArchitecturesInstallIn64BitMode"):
        if not re.search(rf"^{directive}=x64compatible\s*$", source, re.MULTILINE):
            raise AssertionError(f"{directive} must require x64 compatibility")
    error_defaults = re.findall(r"mbError,\s*MB_ABORTRETRYIGNORE,\s*(ID\w+)\)", source)
    if error_defaults != ["IDABORT", "IDABORT"]:
        raise AssertionError("Unattended dependency download/install failures must abort")

    start = source.index("function Dependency_IsVCRuntimeInstalled:")
    end = source.index("procedure Dependency_AddWebView2;", start)
    dependency_code = source[start:end]
    # Keep the real Pascal parsing/version comparison/control flow. Substitute
    # only host inputs and side effects, so tests never read/write the registry
    # or download/execute a redistributable.
    for name in (
        "IsArm64", "RegQueryDWordValue", "RegQueryStringValue", "Log",
        "ExpandConstant", "ExtractTemporaryFile", "Dependency_Add",
    ):
        dependency_code = re.sub(rf"\b{name}\b", "Fixture_" + name, dependency_code)

    output.mkdir(parents=True, exist_ok=True)
    (output / "dependency-under-test.iss").write_text(dependency_code, encoding="utf-8")
    shutil.copyfile(HARNESS, output / HARNESS.name)
    payload = output / "payload"
    payload.mkdir(exist_ok=True)
    (payload / "lantern.exe").write_bytes(b"Compile fixture; never executed.\n")
    dependencies = payload / "installer-dependencies"
    dependencies.mkdir(exist_ok=True)
    redist = dependencies / "VC_redist.x64.exe"
    if os.name == "nt":
        # Any versioned PE exercises GetFileVersion when compiling the complete
        # template. This fixture installer is never executed.
        shutil.copyfile(Path(os.environ["SystemRoot"]) / "System32/cmd.exe", redist)
    else:
        redist.write_bytes(b"Generate-only fixture; no Windows PE available.\n")
    (output / "compile-fixture.iss").write_text(
        render_compile_fixture(source, payload), encoding="utf-8"
    )
    generate_staging_fixture(output)


def run(output, compiler):
    test_staging(output)
    for script in ("compile-fixture.iss", HARNESS.name):
        subprocess.run([compiler, "/Qp", str(output / script)], check=True, timeout=120)

    redist = output / "payload/installer-dependencies/VC_redist.x64.exe"
    versioned_payload = redist.read_bytes()
    try:
        for label, invalid_payload in (("missing", None), ("unversioned", b"not a PE file")):
            redist.unlink(missing_ok=True)
            if invalid_payload is not None:
                redist.write_bytes(invalid_payload)
            failed_compile = subprocess.run(
                [compiler, "/Qp", str(output / "compile-fixture.iss")],
                capture_output=True, text=True, timeout=120,
            )
            if failed_compile.returncode == 0:
                raise AssertionError(f"Installer compiled with {label} redistributable")
            print(f"PASS: installer rejects {label} redistributable")
    finally:
        redist.write_bytes(versioned_payload)

    results = output / "results.txt"
    results.unlink(missing_ok=True)
    log = output / "harness.log"
    completed = subprocess.run(
        [str(output / "windows-installer-test.exe"), "/VERYSILENT", "/SUPPRESSMSGBOXES",
         "/NORESTART", f"/LOG={log}", f"/RESULTS={results}"],
        timeout=60,
    )
    # InitializeSetup deliberately returns False after the tests, so Inno's
    # exit code indicates an aborted setup. A fresh result file is authoritative.
    result = results.read_text(encoding="utf-8-sig").strip() if results.exists() else ""
    if not result.startswith("PASS: "):
        if log.exists():
            print(log.read_text(encoding="utf-8-sig", errors="replace"))
        raise AssertionError(result or f"Harness produced no results (exit {completed.returncode})")
    print(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate-only", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--iscc", default=str(
        Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) /
        "Inno Setup 6/ISCC.exe"
    ))
    args = parser.parse_args()
    output = (args.output or Path(tempfile.mkdtemp(prefix="lantern-installer-test-"))).resolve()
    generate(output)
    print(f"Generated installer test sources: {output}", flush=True)
    if not args.generate_only:
        run(output, args.iscc)


if __name__ == "__main__":
    main()
