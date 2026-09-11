#!/usr/bin/env bash
# GitHub's Windows image already has a usable MinGW toolchain. Install only
# when it is missing, rather than downloading a second compiler onto PATH.
set -euo pipefail

if command -v gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1 &&
  target=$(gcc -dumpmachine 2>/dev/null); then
  if [[ "$target" == x86_64-*-mingw32 ]]; then
    echo "Using preinstalled MinGW ($target)"
    gcc --version
    make --version
    exit 0
  fi
fi

bash "$(dirname "$0")/choco-retry.sh" mingw -y
