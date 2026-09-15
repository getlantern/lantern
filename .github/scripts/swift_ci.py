#!/usr/bin/env python3
"""Decide which native Swift checks a change actually needs.

The macOS and iOS jobs take ~30 minutes each, and most PRs touch neither
platform's inputs. Hash the tracked files each platform actually builds from and
compare against the PR base: an identical fingerprint means nothing that job
consumes has changed, so it can be skipped.

Only a comparison against this PR's own base is used as evidence. Nothing here
reaches the network or trusts state from another run.
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

# Inputs that feed both platforms: Dart and Go sources, generated assets, the
# build configuration, and this planner itself -- a change to how the decision
# is made has to invalidate the decision.
SHARED_FILES = {'go.mod', 'go.sum', 'Makefile', 'pubspec.yaml', 'pubspec.lock',
                '.metadata', '.github/flutter-version.yaml', WORKFLOW, SCRIPT}
SHARED_DIRS = ('lib/', 'assets/', 'lantern-core/', 'scripts/', 'profile/',
               'protos/', 'resources/')


def relevant(path, platform):
    """Whether `path` is an input to `platform`'s native check."""
    return (path in SHARED_FILES or path.startswith(SHARED_DIRS)
            or path.startswith(platform + '/') or path.endswith('.go'))


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
    for platform in PLATFORMS:
        needed, reason = True, 'Native inputs need validation'
        # Manual dispatch is the escape hatch: always rebuild.
        if os.environ['GITHUB_EVENT_NAME'] != 'workflow_dispatch':
            pr = event.get('pull_request')
            if pr and fingerprint(pr['base']['sha'], platform) == fingerprint('HEAD', platform):
                needed, reason = False, 'No platform inputs changed relative to base'
        emit(platform + '_needed', str(needed).lower())
        summary.append(f'| {platform} | {reason} |')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
        output.write('\n'.join(summary) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['plan'])
    parser.parse_args()
    plan(json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text()))
