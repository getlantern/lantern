#!/bin/sh
set -e

UNIT="lanternd.service"

systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now "$UNIT" >/dev/null 2>&1 || true
