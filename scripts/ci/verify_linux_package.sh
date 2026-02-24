#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <path-to-deb>"
	exit 2
fi

DEB_PATH="$1"
if [[ ! -f "$DEB_PATH" ]]; then
	echo "deb package not found: $DEB_PATH"
	exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

dpkg-deb -x "$DEB_PATH" "$TMP_DIR/root"
dpkg-deb -e "$DEB_PATH" "$TMP_DIR/control"

require_file() {
	local path="$1"
	if [[ ! -f "$path" ]]; then
		echo "missing file in package: $path"
		exit 1
	fi
}

require_grep() {
	local pattern="$1"
	local path="$2"
	if ! grep -Eq "$pattern" "$path"; then
		echo "expected pattern '$pattern' not found in: $path"
		exit 1
	fi
}

require_file "$TMP_DIR/root/usr/sbin/lanternd"
require_file "$TMP_DIR/root/usr/lib/systemd/system/lanternd.service"
require_file "$TMP_DIR/control/postinst"

require_grep "ExecStart=/usr/sbin/lanternd" "$TMP_DIR/root/usr/lib/systemd/system/lanternd.service"
require_grep "groupadd --system lantern" "$TMP_DIR/control/postinst"
require_grep "systemctl enable --now lanternd.service" "$TMP_DIR/control/postinst"
require_grep "systemctl is-active --quiet lanternd.service" "$TMP_DIR/control/postinst"

echo "linux package verification passed: $DEB_PATH"
