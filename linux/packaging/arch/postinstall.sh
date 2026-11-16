#!/bin/sh
set -e

# Also used for post_upgrade. pacman passes package versions, not a mode.
if ! /usr/lib/lantern/lanternd install --log-level=info; then
	echo "lantern: failed to install lanternd service" >&2
fi
