#!/bin/bash

if ! type sw_vers >/dev/null 2>&1; then
	echo "This script is for macOS only."
	exit 1
fi

DISABLE_FETCH=0
LOG_PATH=""
DATA_PATH=""
DEV=0
UNSET_LOG=0
UNSET_DATA=0

show_help() {
	cat <<EOF
Usage: $0 <command> [options]

Commands:
  set         Set radiance environment variables
  unset       Unset radiance environment variables
  run-with    Run Lantern app with radiance environment variables (applies only to this run)
  list        List current radiance environment variables and their values

Options:
  --disable-fetch-config   Disables fetching config (RADIANCE_DISABLE_FETCH_CONFIG)
  --log-path [path]        Override log path (RADIANCE_LOG_PATH)
  --data-path [path]       Override data path (RADIANCE_DATA_PATH)
  --dev                    Set environment to 'dev' (RADIANCE_ENV). Default is 'prod'
  --help                   Show this help message

Examples:
  $0 set --log-path /path/to/logs --data-path /path/to/data --disable-fetch-config --dev
  $0 unset --log-path --data-path --disable-fetch-config --dev
  $0 run-with --disable-fetch-config --data-path /path/to/data
  $0 list

Note: For the 'unset' command, do not provide values for any options.
EOF
}

if [[ $# -eq 0 ]]; then
	show_help
	exit 1
fi

COMMAND=""
case "$1" in
set | unset | run-with | list)
	COMMAND="$1"
	shift
	;;
--help)
	show_help
	exit 0
	;;
*)
	echo "Unknown command: $1"
	show_help
	exit 1
	;;
esac

while [[ $# -gt 0 ]]; do
	case "$1" in
	--disable-fetch-config)
		DISABLE_FETCH=1
		shift
		;;
	--dev)
		DEV=1
		shift
		;;
	--log-path)
		if [[ "$COMMAND" == "unset" ]]; then
			UNSET_LOG=1
			shift
		else
			if [[ -z "$2" || "$2" == --* ]]; then
				echo "Error: --log-path requires a value"
				exit 1
			fi
			LOG_PATH="$2"
			shift 2
		fi
		;;
	--data-path)
		if [[ "$COMMAND" == "unset" ]]; then
			UNSET_DATA=1
			shift
		else
			if [[ -z "$2" || "$2" == --* ]]; then
				echo "Error: --data-path requires a value"
				exit 1
			fi
			DATA_PATH="$2"
			shift 2
		fi
		;;
	--help)
		show_help
		exit 0
		;;
	*)
		echo "Unknown option: $1"
		show_help
		exit 1
		;;
	esac
done

case "$COMMAND" in
set)
	[[ -n "$LOG_PATH" ]] && launchctl setenv RADIANCE_LOG_PATH "$LOG_PATH"
	[[ -n "$DATA_PATH" ]] && launchctl setenv RADIANCE_DATA_PATH "$DATA_PATH"
	[[ "$DISABLE_FETCH" -eq 1 ]] && launchctl setenv RADIANCE_DISABLE_FETCH_CONFIG true
	[[ "$DEV" -eq 1 ]] && launchctl setenv RADIANCE_ENV dev
	;;
unset)
	[[ "$UNSET_LOG" -eq 1 ]] && launchctl unsetenv RADIANCE_LOG_PATH
	[[ "$UNSET_DATA" -eq 1 ]] && launchctl unsetenv RADIANCE_DATA_PATH
	[[ "$DISABLE_FETCH" -eq 1 ]] && launchctl unsetenv RADIANCE_DISABLE_FETCH_CONFIG
	[[ "$DEV" -eq 1 ]] && launchctl unsetenv RADIANCE_ENV
	;;
run-with)
	CMD=(open -a "Lantern")
	[[ -n "$LOG_PATH" ]] && CMD+=(--env RADIANCE_LOG_PATH="$LOG_PATH")
	[[ -n "$DATA_PATH" ]] && CMD+=(--env RADIANCE_DATA_PATH="$DATA_PATH")
	[[ "$DISABLE_FETCH" -eq 1 ]] && CMD+=(--env RADIANCE_DISABLE_FETCH_CONFIG=true)
	[[ "$DEV" -eq 1 ]] && CMD+=(--env RADIANCE_ENV=dev)
	"${CMD[@]}"
	;;
list)
	for var in RADIANCE_LOG_PATH RADIANCE_DATA_PATH RADIANCE_DISABLE_FETCH_CONFIG RADIANCE_ENV; do
		value=$(launchctl getenv "$var")
		if [[ -n "$value" ]]; then
			echo "$var=$value"
		else
			echo "$var is not set"
		fi
	done
	;;
esac
