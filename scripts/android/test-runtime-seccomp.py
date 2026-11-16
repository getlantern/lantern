#!/usr/bin/env python3
"""Reproduce the pre-fix Go time64 SIGSYS and verify the pinned runtime.

Requires x86_64 Linux with 32-bit execution, gcc, Go and Python 3.
"""

import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).resolve().parent / "runtime-seccomp"
CONTROL_VERSION = "go1.26.2"
SUCCESS = "runtime-startup-ok"


def run(command, **kwargs):
    print("+ " + " ".join(map(str, command)), flush=True)
    return subprocess.run(command, check=True, timeout=600, **kwargs)


def main():
    if platform.system() != "Linux" or platform.machine() not in ("x86_64", "amd64"):
        raise SystemExit("This regression test requires an x86_64 Linux host (for example ubuntu-24.04 CI).")
    match = re.search(r"^go (\d+\.\d+\.\d+)\s*$", (ROOT / "go.mod").read_text(), re.MULTILINE)
    if not match:
        raise SystemExit("go.mod must pin a patch-level Go toolchain")
    candidate_version = "go" + match[1]
    if candidate_version == CONTROL_VERSION:
        raise SystemExit("The candidate toolchain is the known failing control")

    with tempfile.TemporaryDirectory(prefix="lantern-runtime-seccomp-") as temp:
        directory = Path(temp)
        # Isolate the old toolchain from Lantern's newer go directive.
        (directory / "go.mod").write_text(
            "module lantern-runtime-seccomp-probe\n\ngo " + CONTROL_VERSION[2:] + "\n"
        )
        launcher = directory / "launcher"
        run(["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-O2",
             str(FIXTURE / "launcher.c"), "-o", str(launcher)])
        for version in (CONTROL_VERSION, candidate_version):
            env = dict(os.environ, GOTOOLCHAIN=version, GO111MODULE="on", GOWORK="off",
                       GOOS="linux", GOARCH="386", CGO_ENABLED="0", GOFLAGS="")
            selected = run(["go", "env", "GOVERSION"], env=env, cwd=directory,
                           capture_output=True, text=True).stdout.strip()
            if selected != version:
                raise SystemExit(f"Requested {version}, but Go selected {selected}")
            print(f"Selected toolchain: {selected}", flush=True)
            binary = directory / version
            run(["go", "build", "-o", str(binary), str(FIXTURE / "main.go")],
                env=env, cwd=directory)

            # Verify this executable works without our seccomp fixture first.
            plain = run([str(binary)], capture_output=True, text=True)
            expected = f"{SUCCESS} {version} linux/386"
            if expected not in plain.stdout:
                raise SystemExit(f"Unexpected probe/toolchain output: {plain.stdout!r}")
            print(plain.stdout, end="", flush=True)

            filtered = subprocess.run([str(launcher), str(binary)], capture_output=True,
                                      text=True, timeout=30)
            print(filtered.stdout, end="", flush=True)
            print(filtered.stderr, end="", flush=True)
            if version == CONTROL_VERSION:
                # Go may report SIGSYS itself and exit 2 instead of allowing
                # the kernel's default signal action to terminate the process.
                saw_sigsys = filtered.returncode == -signal.SIGSYS or (
                    filtered.returncode == 2 and "SIGSYS" in filtered.stderr
                )
                if not saw_sigsys or SUCCESS in filtered.stdout:
                    raise SystemExit(f"Control did not reproduce SIGSYS (exit {filtered.returncode})")
                print(f"PASS: {version} reproduces the time64 SIGSYS", flush=True)
            elif filtered.returncode != 0 or expected not in filtered.stdout:
                raise SystemExit(f"Pinned toolchain failed under old-kernel seccomp (exit {filtered.returncode})")
            else:
                print(f"PASS: {version} starts and schedules timers under the same filter", flush=True)


if __name__ == "__main__":
    main()
