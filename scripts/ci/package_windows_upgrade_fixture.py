#!/usr/bin/env python3
"""Package a lower-version installer from the already-built Windows app."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_installer_template import render as render_template


ROOT = Path(__file__).resolve().parents[2]
PACKAGING = ROOT / 'windows/packaging/exe'


def config_value(source, name):
    match = re.search(rf'^{name}:[ \t]*(.+)$', source, re.MULTILINE)
    if not match:
        raise ValueError(f'Missing packaging setting: {name}')
    value = match[1].strip()
    if value.startswith('"'):
        value = json.loads(value)
    elif value.startswith("'") and value.endswith("'"):
        value = value[1:-1].replace("''", "'")
    if not isinstance(value, str) or not value or any(character in value for character in '\r\n#{}'):
        raise ValueError(f'Unsupported packaging setting: {name}')
    return value


def render(template, config, bundle):
    values = {'SOURCE_DIR': str(bundle), 'APP_VERSION': '0.0.0',
              'OUTPUT_BASE_FILENAME': 'upgrade-from'}
    for variable, setting in {
        'APP_ID': 'app_id', 'DISPLAY_NAME': 'display_name',
        'PUBLISHER_NAME': 'publisher', 'PUBLISHER_URL': 'publisher_url',
        'EXECUTABLE_NAME': 'executable_name',
    }.items():
        values[variable] = config_value(config, setting)
    return render_template(template, values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--iscc', default=str(
        Path(os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')) /
        'Inno Setup 6/ISCC.exe'))
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    for name in ('lantern.exe', 'lanternd.exe', 'arm64/lanternd.exe',
                 'installer-dependencies/VC_redist.x64.exe'):
        if not (bundle / name).is_file():
            parser.error(f'Missing Windows app payload: {bundle / name}')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    script = output / 'upgrade-from.iss'
    script.write_text(render((PACKAGING / 'inno_setup.iss').read_text(encoding='utf-8'),
                             (PACKAGING / 'make_config.yaml').read_text(encoding='utf-8'),
                             bundle), encoding='utf-8-sig')
    subprocess.run([args.iscc, '/Qp', f'/O{output}', str(script)], check=True)
    if not (output / 'upgrade-from.exe').is_file():
        raise RuntimeError('Inno Setup did not create the upgrade fixture')


if __name__ == '__main__':
    main()
