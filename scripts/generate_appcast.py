#!/usr/bin/env python3
"""
generate_appcast.py

This script is used to fetch GitHub releases and emits a Sparkle-compatible appcast.xml.
It downloads each platform asset via the asset ID endpoint, parses the associated signatur

Usage:
  export GITHUB_TOKEN=<token>
  python3 scripts/generate_appcast.py
"""
import os
import sys
import subprocess
import tempfile
import re
import requests
import xml.etree.ElementTree as ET

# -------- Configuration --------
REPO = "getlantern/lantern-outline"
OUT_PATH = "appcast.xml"
PLATFORMS = {
    "macos": ".dmg",
    "windows": ".exe",
    "linux": ".AppImage",
}
# --------------------------------


def indent(elem, level=0):
    """Recursively add indentation to XML for pretty-printing."""
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            indent(child, level + 1)
        if not child.tail or not child.tail.strip():
            child.tail = i
    else:
        if level and (not elem.tail or not elem.tail.strip()):
            elem.tail = i


def main():
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        sys.exit("Error: GITHUB_TOKEN variable is not set.")

    api_url = f"https://api.github.com/repos/{REPO}/releases"
    api_headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    resp = requests.get(api_url, headers=api_headers)
    resp.raise_for_status()
    releases = resp.json()

    ET.register_namespace('sparkle', 'http://www.andymatuschak.org/xml-namespaces/sparkle')
    rss = ET.Element('rss', {
        'version': '2.0',
        'xmlns:sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'
    })
    channel = ET.SubElement(rss, 'channel')
    ET.SubElement(channel, 'title').text = 'Lantern'
    ET.SubElement(channel, 'description').text = 'Latest updates for Lantern'
    ET.SubElement(channel, 'language').text = 'en'

    signature_re = re.compile(r'sparkle:edSignature="([^"]+)"')

    for release in releases:
        # skip drafts and prereleases
        if release.get('draft') or release.get('prerelease'):
            continue

        name = release.get('name') or release.get('tag_name')
        tag = release.get('tag_name', '').lstrip('v')
        short_version = tag.split('-')[0]
        pub_date = release.get('published_at')
        assets = release.get('assets', []) or []

        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = name
        ET.SubElement(item, 'sparkle:version').text = tag
        ET.SubElement(item, 'sparkle:shortVersionString').text = short_version
        ET.SubElement(item, 'pubDate').text = pub_date

        # one <enclosure> per platform asset
        for os_name, ext in PLATFORMS.items():
            asset = next((a for a in assets if a.get('name', '').endswith(ext)), None)
            if not asset:
                continue

            asset_id = asset['id']
            download_url = f"https://api.github.com/repos/{REPO}/releases/assets/{asset_id}"
            headers = {
                'Authorization': f"Bearer {token}",
                'Accept': 'application/octet-stream',
                'X-GitHub-Api-Version': '2022-11-28'
            }

            # Download to temp file
            tmpf = tempfile.NamedTemporaryFile(delete=False)
            try:
                with requests.get(download_url, headers=headers, stream=True) as r:
                    r.raise_for_status()
                    for chunk in r.iter_content(chunk_size=8192):
                        tmpf.write(chunk)
                tmpf.close()

                proc = subprocess.run(
                    ['dart', 'run', 'auto_updater:sign_update', tmpf.name],
                    check=True, capture_output=True
                )
                out = proc.stdout.decode().strip()
                m = signature_re.search(out)
                if not m:
                    raise RuntimeError(f"Failed to parse signature from: {out}")
                sig_value = m.group(1)

                size = asset.get('size') or os.path.getsize(tmpf.name)

                # Add enclosure
                ET.SubElement(item, 'enclosure', {
                    'url': f"https://github.com/{REPO}/releases/download/v{tag}/{asset['name']}",
                    'sparkle:edSignature': sig_value,
                    'sparkle:os': os_name,
                    'length': str(size),
                    'type': 'application/octet-stream'
                })

            finally:
                os.unlink(tmpf.name)

    indent(rss)
    tree = ET.ElementTree(rss)
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    tree.write(OUT_PATH, encoding='utf-8', xml_declaration=True)
    print(f"Generated {OUT_PATH}")


if __name__ == '__main__':
    main()
