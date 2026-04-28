#!/bin/sh
set -e

/usr/lib/lantern/lanternd install --log-level=trace >/dev/null 2>&1 || true
