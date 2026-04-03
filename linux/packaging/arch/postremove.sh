#!/bin/sh
set -e

systemctl reset-failed lanternd.service >/dev/null 2>&1 || true
