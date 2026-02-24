#!/bin/sh
set -e

UNIT="lanternd.service"
systemctl stop "$UNIT" >/dev/null 2>&1 || true
