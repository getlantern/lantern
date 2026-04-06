#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${JOIN_SERVER_CONFIG_URLS:-}" ]]; then
  echo "Skipping Linux config URL smoke test (JOIN_SERVER_CONFIG_URLS is not set)."
  exit 0
fi

config_urls_file="$(mktemp)"
cleanup() {
  rm -f "$config_urls_file"
}
trap cleanup EXIT

set +x
printf '%s' "$JOIN_SERVER_CONFIG_URLS" > "$config_urls_file"
chmod 600 "$config_urls_file"
set -x

config_server_base="${JOIN_SERVER_CONFIG_SERVER_NAME:-ci-config-url-smoke-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}}"
config_skip_cert="${JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION:-true}"

sg lantern -c "env PATH=$PATH HOME=$HOME JOIN_SERVER_CONFIG_URLS_FILE=\"$config_urls_file\" JOIN_SERVER_CONFIG_SERVER_NAME=\"${config_server_base}-api\" JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION=\"$config_skip_cert\" xvfb-run -a flutter test integration_test/vpn/linux_config_url_api_smoke_test.dart -d linux --dart-define=DISABLE_SYSTEM_TRAY=true"
sg lantern -c "env PATH=$PATH HOME=$HOME JOIN_SERVER_CONFIG_URLS_FILE=\"$config_urls_file\" JOIN_SERVER_CONFIG_SERVER_NAME=\"${config_server_base}-ui\" JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION=\"$config_skip_cert\" xvfb-run -a flutter test integration_test/vpn/linux_config_url_smoke_test.dart -d linux --dart-define=DISABLE_SYSTEM_TRAY=true"
