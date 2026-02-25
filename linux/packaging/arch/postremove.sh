#!/bin/sh
set -e

UNIT="lanternd.service"

systemctl disable "$UNIT" >/dev/null 2>&1 || true
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
