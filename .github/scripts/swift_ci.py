#!/usr/bin/env python3
"""Compare native build inputs with the PR base or the previous main commit.

Dart changes are checked by flutter-test.yml.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

WORKFLOW = '.github/workflows/swift-compile-check.yml'
SCRIPT = '.github/scripts/swift_ci.py'
PLATFORMS = ('ios', 'macos')
NATIVE_SUFFIXES = {'.go', '.c', '.h', '.cc', '.cpp', '.cxx', '.hpp', '.hh',
                   '.hxx', '.inc', '.m', '.mm', '.swift', '.s', '.rs'}

# Dependencies can affect native plugins. Changes to this gate must also run it.
SHARED_FILES = {'go.mod', 'go.sum', 'Makefile', 'pubspec.yaml', 'pubspec.lock',
                '.metadata', '.github/flutter-version.yaml', WORKFLOW, SCRIPT,
                '.github/scripts/test_swift_ci.py',
                '.github/scripts/swift_framework_cache.py',
                '.github/scripts/test_swift_framework_cache.py'}
SHARED_DIRS = ('lantern-core/', 'hook/', 'scripts/', 'profile/',
               'protos/', 'resources/', '.github/actions/setup-go/',
               '.github/actions/setup-flutter/')
PLATFORM_ASSET_DIRS = {'ios': (), 'macos': ('assets/images/flags/',)}


def relevant(path, platform):
    """Whether `path` is an input to this platform's native check."""
    # make's framework dependencies include Go sources throughout the checkout.
    suffix = Path(path).suffix.lower()
    if suffix == '.go':
        return True
    # Platform-specific files, including Swift/C sources, stay isolated.
    for native_platform in PLATFORMS:
        if path.startswith(native_platform + '/'):
            return platform == native_platform
    foreign_platform = path.startswith(('android/', 'windows/', 'linux/'))
    # The Linux bundle check excludes macOS-only flag assets.
    return (path in SHARED_FILES or path.startswith(SHARED_DIRS)
            or path.startswith(PLATFORM_ASSET_DIRS[platform])
            or (suffix in NATIVE_SUFFIXES and not foreign_platform))


def fingerprint(ref, platform):
    """Digest of every tracked input to `platform` at `ref`.

    Hashes git's own tree metadata, so content, file mode, additions and
    deletions all move the digest. Sorting makes it independent of tree order.
    """
    tree = subprocess.check_output(['git', 'ls-tree', '-rz', '--full-tree', ref])
    entries = []
    for entry in tree.split(b'\0'):
        if not entry:
            continue
        metadata, path = entry.split(b'\t', 1)
        if relevant(path.decode(), platform):
            entries.append(metadata + b'\t' + path)
    return hashlib.sha256(b'\0'.join(sorted(entries))).hexdigest()


def emit(name, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'{name}={value}\n')


def plan(event):
    summary = ['## Swift compile plan', '', '| Platform | Decision |', '|---|---|']
    comparison = None
    event_name = os.environ['GITHUB_EVENT_NAME']
    if event_name == 'pull_request' and event.get('pull_request'):
        comparison = event['pull_request']['base']['sha']
    elif event_name == 'push':
        before = event.get('before')
        if isinstance(before, str) and before and before.strip('0'):
            comparison = before
    for platform in PLATFORMS:
        needed, reason = True, 'Native inputs need validation'
        # Manual dispatch and absent comparison trees always rebuild. A failed
        # tree lookup raises, so the workflow's fail-closed gate runs both jobs.
        if comparison and fingerprint(comparison, platform) == fingerprint('HEAD', platform):
            needed, reason = False, 'Native inputs unchanged'
        emit(platform + '_needed', str(needed).lower())
        summary.append(f'| {platform} | {reason} |')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
        output.write('\n'.join(summary) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['plan'])
    parser.parse_args()
    plan(json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()))
