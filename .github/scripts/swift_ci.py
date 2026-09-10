#!/usr/bin/env python3
"""Plan native checks and find reusable artifacts from successful native jobs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import urlencode

WORKFLOW = '.github/workflows/swift-compile-check.yml'
SCRIPT = '.github/scripts/swift_ci.py'
JOB_NAMES = {
    'ios': 'iOS (Runner + Tunnel, simulator)',
    'macos': 'macOS (Runner + PacketTunnel + RunnerTests)',
}
SHARED_FILES = {'go.mod', 'go.sum', 'Makefile', 'pubspec.yaml', 'pubspec.lock',
                '.metadata', '.github/flutter-version.yaml', WORKFLOW, SCRIPT}
SHARED_DIRS = ('lib/', 'assets/', 'lantern-core/', 'scripts/', 'profile/',
               'protos/', 'resources/')


def relevant(path, platform, framework=False):
    if framework:
        return (path in {'go.mod', 'go.sum', 'Makefile', WORKFLOW, SCRIPT}
                or path.startswith(('lantern-core/', 'scripts/', 'profile/', 'resources/'))
                or path.endswith(('.go', '.c', '.h', '.m', '.s')) and not path.startswith(('ios/', 'macos/', 'android/', 'windows/', 'linux/')))
    return (path in SHARED_FILES or path.startswith(SHARED_DIRS)
            or path.startswith(platform + '/') or path.endswith('.go'))


def fingerprint(ref, platform, framework=False):
    tree = subprocess.check_output(['git', 'ls-tree', '-rz', '--full-tree', ref])
    entries = []
    for entry in tree.split(b'\0'):
        if not entry:
            continue
        metadata, path = entry.split(b'\t', 1)
        if relevant(path.decode(), platform, framework):
            entries.append(metadata + b'\t' + path)
    return hashlib.sha256(b'\0'.join(sorted(entries))).hexdigest()


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], stderr=subprocess.PIPE))


def trusted_run(run, event, repository):
    if run.get('path', '').split('@')[0] != WORKFLOW:
        return False
    if run.get('head_repository', {}).get('full_name') != repository:
        return False
    if run.get('event') == 'push' and run.get('head_branch') == event['repository']['default_branch']:
        return True
    pr = event.get('pull_request')
    return bool(pr and run.get('event') == 'pull_request'
                and any(p['number'] == pr['number'] for p in run.get('pull_requests', [])))


def find_artifact(name, platform, event):
    repository = os.environ['GITHUB_REPOSITORY']
    try:
        result = api(f'repos/{repository}/actions/artifacts?' + urlencode({'name': name, 'per_page': 100}))
        for artifact in result['artifacts']:
            if artifact['expired'] or artifact['name'] != name:
                continue
            run_id = artifact['workflow_run']['id']
            if str(run_id) == os.environ.get('GITHUB_RUN_ID'):
                continue
            run = api(f'repos/{repository}/actions/runs/{run_id}')
            if not trusted_run(run, event, repository):
                continue
            jobs = api(f'repos/{repository}/actions/runs/{run_id}/jobs?per_page=100')['jobs']
            if any(j['name'] == JOB_NAMES[platform] and j['conclusion'] == 'success' for j in jobs):
                return artifact
    except (subprocess.CalledProcessError, KeyError, ValueError) as error:
        print(f'Artifact lookup unavailable ({type(error).__name__}); building instead.')
    return None


def emit(name, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'{name}={value}\n')


def plan(event):
    summary = ['## Swift compile plan', '', '| Platform | Decision |', '|---|---|']
    for platform in JOB_NAMES:
        digest = fingerprint('HEAD', platform)
        name = f'swift-success-v1-{platform}-{digest}'
        emit(platform + '_digest', digest)
        emit(platform + '_marker', name)
        needed, reason = True, 'Native inputs need validation'
        if os.environ['GITHUB_EVENT_NAME'] != 'workflow_dispatch':
            pr = event.get('pull_request')
            if pr and fingerprint(pr['base']['sha'], platform) == digest:
                needed, reason = False, 'No platform inputs changed relative to base'
            else:
                artifact = find_artifact(name, platform, event)
                if artifact:
                    needed = False
                    run_id = artifact['workflow_run']['id']
                    reason = f'Reusing successful [run {run_id}](https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{run_id})'
        emit(platform + '_needed', str(needed).lower())
        summary.append(f'| {platform} | {reason} |')
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
        output.write('\n'.join(summary) + '\n')


def framework(platform, event):
    toolchain = b'\0'.join(subprocess.check_output(command) for command in (
        ['go', 'version'], ['xcodebuild', '-version'], ['xcrun', '--sdk', 'iphonesimulator' if platform == 'ios' else 'macosx', '--show-sdk-version'], ['uname', '-m']))
    digest = hashlib.sha256(fingerprint('HEAD', platform, framework=True).encode() + toolchain).hexdigest()
    name = f'swift-framework-v1-{platform}-{digest}'
    emit('name', name)
    artifact = find_artifact(name, platform, event)
    emit('artifact_id', artifact['id'] if artifact else '')
    emit('run_id', artifact['workflow_run']['id'] if artifact else '')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['plan', 'framework'])
    parser.add_argument('--platform', choices=JOB_NAMES)
    args = parser.parse_args()
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    if args.command == 'plan':
        plan(event)
    else:
        framework(args.platform, event)
