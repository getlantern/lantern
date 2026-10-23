#!/bin/sh
set -e

/usr/lib/lantern/lanternd install --log-level=info >/dev/null 2>&1 || true
