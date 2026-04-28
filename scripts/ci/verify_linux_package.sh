#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
	echo "usage: $0 <path-to-deb> [expected-arch]"
	exit 2
fi

DEB_PATH="$1"
EXPECTED_ARCH="${2:-}"
if [[ ! -f "$DEB_PATH" ]]; then
	echo "deb package not found: $DEB_PATH"
	exit 1
fi

if [[ -n "$EXPECTED_ARCH" ]]; then
	PKG_ARCH="$(dpkg-deb -f "$DEB_PATH" Architecture)"
	if [[ "$PKG_ARCH" != "$EXPECTED_ARCH" ]]; then
		echo "package architecture mismatch: expected '$EXPECTED_ARCH', got '$PKG_ARCH'"
		exit 1
	fi
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

require_file "$TMP_DIR/root/usr/lib/lantern/lanternd"
require_file "$TMP_DIR/root/usr/lib/lantern/lantern"
require_file "$TMP_DIR/control/postinst"

require_grep "lanternd install" "$TMP_DIR/control/postinst"

echo "linux package verification passed: $DEB_PATH"
