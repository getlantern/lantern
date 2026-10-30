#!/usr/bin/env python3
"""Build the pinned NDK C++ runtime with stack protection, without changing the NDK.

The source manifest mirrors the runtime sources and ordered Android patches in
NDK r28c's clang_source_info.md / llvm_android PATCHES.json. Only runtime and
CMake subtrees are downloaded (about 9 MB), not the entire LLVM toolchain.
"""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

if os.name == "nt":
    import msvcrt
else:
    import fcntl


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
MANIFEST = HERE / "hardened-libcxx-sources.json"
TARGETS = {
    "arm64-v8a": ("aarch64-linux-android", "aarch64-linux-android"),
    "armeabi-v7a": ("armv7a-linux-androideabi", "arm-linux-androideabi"),
    "x86_64": ("x86_64-linux-android", "x86_64-linux-android"),
    "x86": ("i686-linux-android", "i686-linux-android"),
}
API = 23
HARDENING = "-fstack-protector-strong -D_FORTIFY_SOURCE=2"
LINK_FLAGS = "-Wl,-z,relro,-z,now,-z,noexecstack,-z,max-page-size=16384,-z,common-page-size=16384 -Wl,--build-id=sha1"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def capture(args):
    return subprocess.check_output([str(arg) for arg in args], text=True)


def tool(toolchain, name):
    return toolchain / "bin" / (name + (".exe" if os.name == "nt" else ""))


def fetch(url, path, expected, encoded=False):
    if path.is_file() and digest(path) == expected:
        return
    print(f"Downloading {path.name}", flush=True)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=90) as response:
                data = response.read()
            if encoded:
                data = base64.b64decode(data)
            if hashlib.sha256(data).hexdigest() != expected:
                raise RuntimeError(f"SHA256 mismatch for {url}")
            path.write_bytes(data)
            return
        except (OSError, urllib.error.URLError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def prepare_source(work, manifest):
    source = work / "source"
    stamp = work / "source.sha256"
    source_key = hashlib.sha256((digest(MANIFEST) + digest(Path(__file__))).encode()).hexdigest()
    if source.is_dir() and stamp.is_file() and stamp.read_text() == source_key:
        return source
    downloads = work / "downloads"
    downloads.mkdir(exist_ok=True)
    llvm_url = "https://android.googlesource.com/toolchain/llvm-project/+archive/"
    android_url = "https://android.googlesource.com/toolchain/llvm_android/+/"
    with tempfile.TemporaryDirectory(dir=work, prefix="source-") as temporary:
        extracted = Path(temporary)
        for item in manifest["archives"]:
            archive = downloads / (item["path"].replace("/", "-") + ".tar.gz")
            fetch(f"{llvm_url}{manifest['llvm_revision']}/{item['path']}.tar.gz", archive, item["sha256"])
            target = extracted / item["path"]
            target.mkdir(parents=True, exist_ok=True)
            with tarfile.open(archive) as contents:
                for member in contents.getmembers():
                    if member.name.startswith("/") or ".." in Path(member.name).parts:
                        raise RuntimeError(f"Unsafe archive entry: {member.name}")
                    if not (member.isfile() or member.isdir()):
                        raise RuntimeError(f"Unsupported archive entry: {member.name}")
                contents.extractall(target)
        for item in manifest["patches"]:
            patch = downloads / Path(item["path"]).name
            fetch(f"{android_url}{manifest['android_revision']}/patches/{item['path']}?format=TEXT", patch, item["sha256"], encoded=True)
            # Do not discover Lantern's parent checkout and silently skip paths
            # because this standalone source tree is in a repo subdirectory.
            patch_env = dict(os.environ, GIT_CEILING_DIRECTORIES=str(work))
            run(["git", "apply", *[f"--include={item['path']}/**" for item in manifest["archives"]], patch], cwd=extracted, env=patch_env)
        if source.exists():
            shutil.rmtree(source)
        shutil.move(str(extracted), source)
    stamp.write_text(source_key)
    return source


def cmake_options(ndk, ninja, abi):
    # Preserve NDK r28c's ABI configuration and profiling flags. The unwinder
    # is rebuilt too, so no unprotected prebuilt C++ objects are copied in.
    profile = " -fdebug-info-for-profiling -mllvm -enable-fs-discriminator=true -mllvm -improved-fs-discriminator=true"
    flags = HARDENING + " -D_LIBUNWIND_USE_DLADDR=0" + profile
    return {
        "CMAKE_MAKE_PROGRAM": str(ninja),
        "CMAKE_TOOLCHAIN_FILE": str(ndk / "build/cmake/android.toolchain.cmake"),
        "ANDROID_ABI": abi,
        "ANDROID_PLATFORM": f"android-{API}",
        "ANDROID_STL": "none",
        "CMAKE_BUILD_TYPE": "RelWithDebInfo",
        "CMAKE_C_FLAGS": flags,
        "CMAKE_CXX_FLAGS": flags + " -DHAS_THREAD_LOCAL",
        "CMAKE_SHARED_LINKER_FLAGS": LINK_FLAGS,
        "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",
        "LLVM_ENABLE_RUNTIMES": "libunwind;libcxxabi;libcxx",
        "LLVM_ENABLE_PER_TARGET_RUNTIME_DIR": "OFF",
        "LLVM_INCLUDE_TESTS": "OFF",
        "LIBUNWIND_INCLUDE_TESTS": "OFF",
        "LIBCXX_INCLUDE_TESTS": "OFF",
        "LIBCXXABI_INCLUDE_TESTS": "OFF",
        "LIBCXX_INCLUDE_BENCHMARKS": "OFF",
        "LIBUNWIND_ENABLE_SHARED": "OFF",
        "LIBUNWIND_HIDE_SYMBOLS": "ON",
        "LIBUNWIND_USE_FRAME_HEADER_CACHE": "OFF",
        "LIBUNWIND_USE_COMPILER_RT": "ON",
        "LIBCXXABI_ENABLE_SHARED": "OFF",
        "LIBCXXABI_USE_LLVM_UNWINDER": "ON",
        "LIBCXXABI_ENABLE_STATIC_UNWINDER": "ON",
        "LIBCXXABI_USE_COMPILER_RT": "ON",
        "LIBCXX_ENABLE_SHARED": "ON",
        "LIBCXX_ENABLE_STATIC": "OFF",
        "LIBCXX_SHARED_OUTPUT_NAME": "c++_shared",
        "LIBCXX_ENABLE_ABI_LINKER_SCRIPT": "OFF",
        "LIBCXX_ENABLE_STATIC_ABI_LIBRARY": "ON",
        "LIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY": "ON",
        "LIBCXX_ABI_VERSION": "1",
        "LIBCXX_ABI_NAMESPACE": "__ndk1",
        # Match NDK's default: retain libc++'s exported __muloti4 definition.
        # Android Clang still selects compiler-rt for compiler builtins.
        "LIBCXX_USE_COMPILER_RT": "OFF",
        "LIBCXX_ENABLE_TIME_ZONE_DATABASE": "OFF",
        "LIBCXX_PSTL_CPU_BACKEND": "std_thread",
    }


def exports(readelf, library):
    result = set()
    for line in capture([readelf, "--dyn-syms", "--wide", library]).splitlines():
        fields = line.split()
        if len(fields) >= 8 and fields[4] in ("GLOBAL", "WEAK") and fields[5] in ("DEFAULT", "PROTECTED") and fields[6] != "UND":
            result.add(fields[7])  # Keep symbol versions, if present.
    return result


def validate(toolchain, abi, library, build):
    readelf = tool(toolchain, "llvm-readelf")
    stock = toolchain / "sysroot/usr/lib" / TARGETS[abi][1] / "libc++_shared.so"
    missing = exports(readelf, stock) - exports(readelf, library)
    if missing:
        raise RuntimeError("Rebuilt runtime omits NDK exports: " + ", ".join(sorted(missing)))
    program = capture([readelf, "-lW", library])
    dynamic = capture([readelf, "-dW", library])
    stock_dynamic = capture([readelf, "-dW", stock])
    needed = lambda data: set(re.findall(r"\(NEEDED\).*\[(.*?)\]", data))
    if needed(dynamic) != needed(stock_dynamic) or "[libc++_shared.so]" not in dynamic:
        raise RuntimeError("Rebuilt runtime changed its SONAME or dependencies")
    stack = next((line for line in program.splitlines() if "GNU_STACK" in line), "")
    if not stack or " E " in stack or "RWE" in stack or "GNU_RELRO" not in program or "BIND_NOW" not in dynamic:
        raise RuntimeError("Rebuilt runtime lacks NX/full RELRO")
    for line in program.splitlines():
        if line.strip().startswith("LOAD") and int(line.split()[-1], 16) < 16384:
            raise RuntimeError("Rebuilt runtime lacks 16 KB LOAD alignment")
    if "__stack_chk_fail" not in capture([readelf, "--dyn-syms", "--wide", library]):
        raise RuntimeError("Rebuilt runtime lacks stack canary checks")
    # Compile against the unmodified NDK headers and link against only the new
    # shared runtime, covering std::string allocation and C++ exception ABI.
    smoke = build / "libcxx-smoke.cpp"
    smoke.write_text('#include <string>\n#include <stdexcept>\nint main() {\n  try { throw std::runtime_error(std::string(100, \'x\')); }\n  catch (const std::exception& e) { return std::string(e.what()).size() == 100 ? 0 : 1; }\n}\n')
    run([tool(toolchain, "clang++"), f"--target={TARGETS[abi][0]}{API}", "-std=c++17", "-fstack-protector-strong", "-nostdlib++", smoke, library, "-o", build / "libcxx-smoke"])
    return {"stock_exports": len(exports(readelf, stock)), "rebuilt_exports": len(exports(readelf, library)), "needed": sorted(needed(dynamic)), "smoke_test": "compiled and linked; device execution required"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ndk", type=Path)
    parser.add_argument("--abis", default="arm64-v8a,armeabi-v7a")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "bin/android/libcxx")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "build/android-hardened-libcxx")
    parser.add_argument("--cmake")
    parser.add_argument("--ninja")
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    ndk = args.ndk or os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    if not ndk and sdk:
        ndk = Path(sdk) / "ndk" / manifest["ndk_version"]
    if not ndk:
        parser.error("Pass --ndk or set ANDROID_HOME / ANDROID_NDK_HOME")
    ndk = Path(ndk).resolve()
    properties = (ndk / "source.properties").read_text()
    if not re.search(r"^Pkg.Revision\s*=\s*" + re.escape(manifest["ndk_version"]) + r"\s*$", properties, re.M):
        parser.error(f"This source manifest requires NDK {manifest['ndk_version']}: {ndk}")
    host = {"Darwin": "darwin-x86_64", "Linux": "linux-x86_64", "Windows": "windows-x86_64"}.get(platform.system())
    if not host:
        parser.error(f"Unsupported NDK host: {platform.system()}")
    toolchain = ndk / "toolchains/llvm/prebuilt" / host
    sdk_cmake = sorted((ndk.parent.parent / "cmake").glob("*/bin"), key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name)), reverse=True)
    def executable(explicit, name):
        filename = name + (".exe" if os.name == "nt" else "")
        candidate = explicit or next((str(p / filename) for p in sdk_cmake if (p / filename).is_file()), None) or shutil.which(name)
        if not candidate:
            parser.error(f"Install {name} or pass --{name}")
        return str(Path(candidate).resolve())
    cmake, ninja = executable(args.cmake, "cmake"), executable(args.ninja, "ninja")
    abis = args.abis.split(",")
    if not abis or any(abi not in TARGETS for abi in abis):
        parser.error(f"Unsupported ABI list: {args.abis}")
    work = args.work_dir.resolve()
    output = args.output_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    # Gradle may configure several ABIs concurrently. Share downloads safely.
    with (work / ".lock").open("a+b") as lock:
        if os.name == "nt":
            lock.write(b"0")
            lock.flush()
            while True:
                lock.seek(0)
                try:
                    msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
                    break
                except OSError:
                    time.sleep(1)
        else:
            fcntl.flock(lock, fcntl.LOCK_EX)
        for abi in abis:
            options = cmake_options(ndk, ninja, abi)
            key_data = {"script": digest(Path(__file__)), "manifest": digest(MANIFEST), "ndk": properties, "clang": (toolchain / "AndroidVersion.txt").read_text(), "cmake": capture([cmake, "--version"]), "options": options}
            key = hashlib.sha256(json.dumps(key_data, sort_keys=True).encode()).hexdigest()
            destination = output / abi
            library = destination / "libc++_shared.so"
            receipt = destination / "build.json"
            if library.is_file() and receipt.is_file():
                saved = json.loads(receipt.read_text())
                if saved.get("build_key") == key and saved.get("sha256") == digest(library):
                    print(f"Hardened libc++ {abi}: verified cached build", flush=True)
                    continue
            source = prepare_source(work, manifest)
            build = work / abi
            build_stamp = build / ".build-key"
            if build.exists() and (not build_stamp.is_file() or build_stamp.read_text() != key):
                # Archives retain old source mtimes: Ninja must not reuse objects
                # compiled from a previous source/patch/toolchain configuration.
                shutil.rmtree(build)
            build.mkdir(exist_ok=True)
            build_stamp.write_text(key)
            log_path = work / f"{abi}.log"
            print(f"Building hardened libc++ {abi} (log: {log_path})", flush=True)
            try:
                with log_path.open("w") as log:
                    run([cmake, "-G", "Ninja", "-S", source / "runtimes", "-B", build, *[f"-D{k}={v}" for k, v in options.items()]], stdout=log, stderr=subprocess.STDOUT)
                    run([cmake, "--build", build, "--target", "cxx_shared", "--parallel", args.jobs], stdout=log, stderr=subprocess.STDOUT)
                built = build / "lib/libc++_shared.so"
                checks = validate(toolchain, abi, built, build)
            except subprocess.CalledProcessError:
                print(log_path.read_text()[-12000:], file=sys.stderr)
                raise
            destination.mkdir(parents=True, exist_ok=True)
            temporary = destination / "libc++_shared.so.tmp"
            run([tool(toolchain, "llvm-strip"), "--strip-unneeded", "-o", temporary, built])
            temporary.replace(library)
            for component in ("libcxx", "libcxxabi", "libunwind"):
                shutil.copyfile(source / component / "LICENSE.TXT", destination / f"LICENSE.{component}.txt")
            receipt.write_text(json.dumps({"build_key": key, "sha256": digest(library), "sources": manifest, "configuration": options, "validation": checks}, indent=2) + "\n")
            print(f"Hardened libc++ {abi}: built and validated", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(f"hardened libc++: {error}")
