#!/usr/bin/env python3
"""Cache keys for CI frameworks and Pods, including native inputs and toolchains."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


CONFIG_FILES = {'go.mod', 'go.sum', 'Makefile',
                '.github/scripts/swift_framework_cache.py',
                '.github/workflows/swift-compile-check.yml'}
NATIVE_EXTENSIONS = {'.go', '.c', '.h', '.s', '.S', '.cc', '.cpp', '.cxx',
                     '.hpp', '.hh', '.hxx', '.inc', '.m', '.mm', '.f', '.F',
                     '.for', '.f90', '.syso', '.a', '.def', '.pc'}


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def tracked_files():
    return [Path(path) for path in command('git', 'ls-files', '-z').split('\0') if path]


def framework_inputs(paths):
    package_dirs = {path.parent for path in paths
                    if path.suffix == '.go' and not path.name.endswith('_test.go')}
    embedded_dirs = {path.parent for path in paths
                     if path.suffix == '.go' and not path.name.endswith('_test.go')
                     and re.search(rb'^[ \t]*//go:embed\s', path.read_bytes(), re.MULTILINE)}
    selected = []
    for path in paths:
        if any(path.is_relative_to(directory) for directory in embedded_dirs):
            selected.append(path)
        elif not path.name.endswith('_test.go') and (
                str(path) in CONFIG_FILES
                or str(path).startswith('.github/actions/setup-go/')
                or path.suffix in NATIVE_EXTENSIONS
                or any(path.is_relative_to(directory) for directory in package_dirs)):
            selected.append(path)
    return selected


def digest_files(paths):
    digest = hashlib.sha256()
    for path in sorted(paths):
        # Include names and modes so a renamed/deleted input cannot collide.
        digest.update(str(path).encode() + b'\0')
        digest.update(str(path.lstat().st_mode).encode() + b'\0')
        digest.update(path.read_bytes() + b'\0')
    return digest.hexdigest()


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def toolchain(platform, arch):
    sdk = 'iphonesimulator' if platform == 'ios' else 'macosx'
    target = ('iossimulator/' if platform == 'ios' else 'macos/') + arch
    return {'target': target, 'host': command('uname', '-m'),
            'macos': command('sw_vers', '-productVersion'),
            'xcode': command('xcodebuild', '-version'),
            'sdk': command('xcrun', '--sdk', sdk, '--show-sdk-build-version'),
            'go': command('go', 'version'),
            'go_environment': command('go', 'env', '-json', 'GOEXPERIMENT',
                                      'GOAMD64', 'GOARM64', 'CGO_ENABLED'),
            'identity': 'swift-check-v1'}


def cache_keys(platform, arch, paths, tools):
    framework = digest({'inputs': digest_files(framework_inputs(paths)),
                        'toolchain': tools})
    pod_paths = [path for path in paths if str(path) in {
        f'{platform}/Podfile', f'{platform}/Podfile.lock',
        'pubspec.yaml', 'pubspec.lock', '.github/flutter-version.yaml'}]
    # Generated Pods projects are toolchain-specific; downloaded dependencies
    # can still be reused when only the lockfile/plugin inputs change.
    pod_tools = {key: value for key, value in tools.items()
                 if key not in {'go', 'go_environment', 'identity'}}
    pod_tools['cocoapods'] = command('pod', '--version')
    pod_tools['flutter'] = digest_files([Path('.github/flutter-version.yaml')])
    prefix = f'swift-pods-v2-{platform}-{arch}-{digest(pod_tools)}-'
    return {'framework_key': f'swift-framework-v2-{platform}-{arch}-{framework}',
            'pods_key': prefix + digest_files(pod_paths), 'pods_prefix': prefix}


def validate_environment():
    # Custom compiler flags or local replacements are not represented by the
    # standard CI recipe. Fail rather than restore an incompatible framework.
    for name in ('GOFLAGS', 'CGO_CFLAGS', 'CGO_CPPFLAGS', 'CGO_CXXFLAGS',
                 'CGO_LDFLAGS', 'EXTRA_LDFLAGS', 'STEALTH_MODE', 'STEALTH_PROFILE'):
        if os.environ.get(name):
            raise ValueError(f'{name} is unsupported by the Swift-check cache')
    if command('go', 'env', 'GOFLAGS'):
        raise ValueError('Go environment GOFLAGS is unsupported by the Swift-check cache')
    modules = json.loads(command('go', 'mod', 'edit', '-json'))
    if any(not replacement['New'].get('Version') for replacement in modules.get('Replace') or []):
        raise ValueError('Local module replacements are unsupported by the Swift-check cache')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', required=True, choices=('ios', 'macos'))
    parser.add_argument('--arch', required=True, choices=('arm64', 'amd64'))
    args = parser.parse_args()
    if os.environ.get('SWIFT_CHECK') != '1' or os.environ.get('SWIFT_CHECK_ARCH') != args.arch:
        parser.error('SWIFT_CHECK=1 and matching SWIFT_CHECK_ARCH are required')
    validate_environment()
    keys = cache_keys(args.platform, args.arch, tracked_files(), toolchain(args.platform, args.arch))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        for name, value in keys.items():
            output.write(f'{name}={value}\n')
