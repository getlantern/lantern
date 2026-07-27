.PHONY: gen macos

# Flutter builds directory
BUILD_DIR := build
# Go builds directory
BIN_DIR := bin
DIST_OUT := dist

APP ?= lantern
INSTALLER_NAME ?= lantern-installer
CAPITALIZED_APP := Lantern
LANTERN_LIB_NAME := liblantern
LANTERN_CORE := lantern-core
RADIANCE_REPO := github.com/getlantern/radiance
FFI_DIR := $(LANTERN_CORE)/ffi
## APP_VERSION is the full version from pubspec.yaml (e.g. 9.0.25+459).
## Precedence: environment > pubspec.yaml. CI must export APP_VERSION — on
## Windows CI, `$(shell …)` runs under cmd.exe which mangles the Unix-style
## quoting in the grep|sed pipeline and returns empty, producing an empty
## `common.Version` ldflag and a 400 "missing app version" at /v1/config-new.
## Local builds fall back to reading pubspec.yaml directly, with a PowerShell
## branch so Windows devs without Git Bash / WSL still get a working build.
##
## Caveat: pubspec.yaml's `version:` is a hardcoded literal that lags the real
## release line — it is only rewritten to the authoritative version in CI (by
## release.yml, from scripts/ci/version.sh). A local build still resolves its Go
## deps from go.mod (current code) but would stamp that stale literal, so
## sideload/dev builds get mislabeled (e.g. 9.0.28) in telemetry and support
## tickets. Outside CI, derive the version from git tags first; the pubspec
## fallback below only applies if that yields nothing (e.g. a checkout with no
## tags). In CI, GITHUB_ACTIONS is set, so we skip this and trust the rewritten
## pubspec. The version.sh derivation lives in the non-Windows branch only: it's
## a bash script and `2>/dev/null` is a POSIX redirection, neither of which
## behaves under cmd.exe, so Windows devs fall through to the PowerShell read.
ifeq ($(OS),Windows_NT)
APP_VERSION ?= $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command '(Select-String -Path "pubspec.yaml" -Pattern "^version:\s*(.+)$$").Matches[0].Groups[1].Value.Trim()')
else
## Only derive when the caller hasn't already supplied APP_VERSION (env or
## command line). This honors the documented precedence (environment > pubspec)
## and avoids both the cost of running version.sh and a misleading fallback
## warning when the value is overridden.
ifndef APP_VERSION
ifndef GITHUB_ACTIONS
## Capture into a temp so we only set APP_VERSION when version.sh actually
## produced output. A bare `APP_VERSION ?= $(shell …)` would *define*
## APP_VERSION as empty when version.sh fails (no tags, shallow clone, a sort
## without -V, …), turning the pubspec fallback below into a no-op and tripping
## the "is empty" $(error). On empty: warn and fall through to pubspec.
LANTERN_DERIVED_VERSION := $(shell ./scripts/ci/version.sh generate nightly 2>/dev/null)
ifneq ($(strip $(LANTERN_DERIVED_VERSION)),)
APP_VERSION := $(LANTERN_DERIVED_VERSION)
else
$(warning could not derive version from scripts/ci/version.sh; falling back to pubspec.yaml — the build version may be stale)
endif
endif
endif
APP_VERSION ?= $(shell grep '^version:' pubspec.yaml | sed 's/version: //;s/ //g')
endif
## Freeze APP_VERSION after resolution. `?=` leaves it recursively expanded, so
## every later $(APP_VERSION) reference would re-run the $(shell …) — and
## version.sh embeds a timestamp, so the value could drift between recipe
## invocations (e.g. the deb/rpm/arch packages built sequentially in
## linux-release-ci). The `:=` self-assignment evaluates it exactly once, here.
APP_VERSION := $(APP_VERSION)
## Strip the +buildnumber for the Go linker. Done with Make built-ins so no
## shell tools are required — this is the part that has to work in every
## environment `make` might invoke the linker in.
APP_VERSION_PUBSPEC := $(firstword $(subst +, ,$(APP_VERSION)))
## Fail loudly at parse time if we couldn't resolve a version — this was the
## exact failure mode of the bug this file fixes, where an empty value silently
## produced a broken binary that 400s at /v1/config-new.
ifeq ($(strip $(APP_VERSION_PUBSPEC)),)
$(error APP_VERSION_PUBSPEC is empty; export APP_VERSION (e.g. "9.0.25+459") or ensure pubspec.yaml contains a `version:` line)
endif
EXTRA_LDFLAGS ?= -X '$(RADIANCE_REPO)/common.Version=$(APP_VERSION_PUBSPEC)'
STEALTH_GO_IMPORT_PATH := github.com/getlantern/lantern/lantern-core
STEALTH_GO_LOG_LEVEL ?= warn
# Stealth can be activated via a stealth BUILD_TYPE or via STEALTH_MODE/STEALTH_PROFILE
# (which leave BUILD_TYPE=production), so gate stealth flags on all three signals.
STEALTH_ACTIVE := $(strip $(filter stealth stealth-%,$(BUILD_TYPE))$(STEALTH_MODE)$(STEALTH_PROFILE))
STEALTH_GO_LDFLAGS := $(if $(STEALTH_ACTIVE),-X '$(STEALTH_GO_IMPORT_PATH).StealthBuild=true' -X '$(STEALTH_GO_IMPORT_PATH).StealthLogLevel=$(STEALTH_GO_LOG_LEVEL)')
GO_EXTRA_LDFLAGS := $(strip $(EXTRA_LDFLAGS) $(STEALTH_GO_LDFLAGS))
LANTERND_EXTRA_LDFLAGS := $(EXTRA_LDFLAGS)

DARWIN_APP_NAME := $(CAPITALIZED_APP).app
DARWIN_LIB := $(LANTERN_LIB_NAME).dylib
DARWIN_LIB_AMD64 := $(BIN_DIR)/macos-amd64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_ARM64 := $(BIN_DIR)/macos-arm64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_BUILD := $(BIN_DIR)/macos/$(DARWIN_LIB)
DARWIN_RELEASE_DIR := $(BUILD_DIR)/macos/Build/Products/Release
DARWIN_DEBUG_BUILD := $(BUILD_DIR)/macos/Build/Products/Debug/$(DARWIN_APP_NAME)
DARWIN_RELEASE_BUILD := $(DARWIN_RELEASE_DIR)/$(DARWIN_APP_NAME)
MACOS_ENTITLEMENTS := macos/Runner/Release.entitlements
MACOS_INSTALLER := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).dmg
MACOS_DIR := macos/
MACOS_FRAMEWORK := Liblantern.xcframework
MACOS_FRAMEWORK_DIR := macos/Frameworks
MACOS_FRAMEWORK_BUILD := $(BIN_DIR)/macos/$(MACOS_FRAMEWORK)
MACOS_FRAMEWORK_OUTPUT := $(MACOS_FRAMEWORK_DIR)/$(MACOS_FRAMEWORK)
MACOS_DEBUG_BUILD := $(BUILD_DIR)/macos/Runner.app
MACOS_FFI_HEADER := $(BIN_DIR)/macos-arm64/$(LANTERN_LIB_NAME).h
PACKET_TUNNEL_DIR := $(DARWIN_RELEASE_BUILD)/Contents/PlugIns/PacketTunnel.appex
SYSTEM_EXTENSION_DIR := $(DARWIN_RELEASE_DIR)/$(DARWIN_APP_NAME)/Contents/Library/SystemExtensions/org.getlantern.lantern.PacketTunnel.systemextension
PACKET_ENTITLEMENTS := macos/PacketTunnel/PacketTunnel.entitlements

LINUX_LIB := $(LANTERN_LIB_NAME).so
LINUX_LIB_AMD64 := $(BIN_DIR)/linux-amd64/$(LANTERN_LIB_NAME).so
LINUX_LIB_ARM64 := $(BIN_DIR)/linux-arm64/$(LANTERN_LIB_NAME).so
LINUX_LIB_BUILD := $(BIN_DIR)/linux/$(LINUX_LIB)
LINUX_TARGET_ARCH ?= amd64
LINUX_PACKAGE_ARCH_SUFFIX := $(if $(filter amd64,$(LINUX_TARGET_ARCH)),,-$(LINUX_TARGET_ARCH))
LINUX_INSTALLER_DEB := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE))$(LINUX_PACKAGE_ARCH_SUFFIX).deb
LINUX_INSTALLER_RPM := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE))$(LINUX_PACKAGE_ARCH_SUFFIX).rpm
LINUX_INSTALLER_ARCH := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE))$(LINUX_PACKAGE_ARCH_SUFFIX).pkg.tar.zst
LANTERND := lanternd
LANTERND_SRC := $(RADIANCE_REPO)/cmd/lanternd
LANTERND_SERVICE_LOG_LEVEL ?= $(if $(STEALTH_ACTIVE),warn,trace)
LANTERND_LINUX_AMD64 := $(BIN_DIR)/linux-amd64/$(LANTERND)
LANTERND_LINUX_ARM64 := $(BIN_DIR)/linux-arm64/$(LANTERND)
LINUX_BUNDLE_DIR_X64 := build/linux/x64/release/bundle
LINUX_BUNDLE_DIR_ARM64 := build/linux/arm64/release/bundle
LINUX_CC_AMD64 ?= x86_64-linux-gnu-gcc
LINUX_CC_ARM64 ?= aarch64-linux-gnu-gcc
LINUX_PKG_ROOT := linux/packaging

ifeq ($(OS),Windows_NT)
  PS := powershell -NoProfile -ExecutionPolicy Bypass -Command
  MKDIR_P = $(PS) "New-Item -ItemType Directory -Force -Path '$(1)' | Out-Null"
  COPY_FILE = $(PS) "Copy-Item -Force -LiteralPath '$(1)' -Destination '$(2)'"
  RM_RF = $(PS) "Remove-Item -Recurse -Force -LiteralPath '$(1)'"
  WRITE_TEXT_FILE = $(PS) "Set-Content -LiteralPath '$(2)' -Value '$(1)' -Encoding ASCII"
else
  MKDIR_P = mkdir -p -- '$(1)'
  COPY_FILE = cp -f -- '$(1)' '$(2)'
  RM_RF = rm -rf -- '$(1)'
  WRITE_TEXT_FILE = printf '%s\n' '$(1)' > '$(2)'
endif

LANTERND_WINDOWS_AMD64 := $(BIN_DIR)/windows-amd64/$(LANTERND).exe
LANTERND_WINDOWS_ARM64 := $(BIN_DIR)/windows-arm64/$(LANTERND).exe

WINDOWS_LIB          := $(LANTERN_LIB_NAME).dll
WINDOWS_LIB_AMD64    := $(BIN_DIR)/windows-amd64/$(WINDOWS_LIB)
WINDOWS_LIB_ARM64    := $(BIN_DIR)/windows-arm64/$(WINDOWS_LIB)
WINDOWS_LIB_BUILD    := $(BIN_DIR)/windows/$(WINDOWS_LIB)
WINDOWS_DEBUG_DIR    := $(BUILD_DIR)/windows/x64/runner/Debug
WINDOWS_RELEASE_DIR  := $(BUILD_DIR)/windows/x64/runner/Release
LANTERND_WINDOWS_RELEASE := $(WINDOWS_RELEASE_DIR)/$(LANTERND).exe
LANTERND_WINDOWS_RELEASE_ARM64 := $(WINDOWS_RELEASE_DIR)/arm64/$(LANTERND).exe


ANDROID_LIB := $(LANTERN_LIB_NAME).aar
ANDROID_LIBS_DIR := android/app/libs
ANDROID_LIB_BUILD := $(BIN_DIR)/android/$(ANDROID_LIB)
ANDROID_LIB_PATH := android/app/libs/$(LANTERN_LIB_NAME).aar
ANDROID_DEBUG_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-debug.apk
ANDROID_APK_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
# ABI targeting: arm64-only for both APK and AAB (2026-05-28).
#
# armeabi-v7a (32-bit) was dropped from the AAB too: Go >=1.23.2 trips
# Android 8-10 seccomp on 32-bit, killing libgojni.so with SIGSYS at startup
# (golang/go#70495 — ~54% of v9 crashes; those devices were crash-looping
# anyway). Re-add android-arm here if/when that's fixed upstream.
ANDROID_APK_TARGET_PLATFORMS := android-arm64
ANDROID_AAB_TARGET_PLATFORMS := android-arm64
# Back-compat alias for any external caller / debug target that references
# ANDROID_TARGET_PLATFORMS. Now arm64-only, same as the APK/AAB targets.
ANDROID_TARGET_PLATFORMS := $(ANDROID_AAB_TARGET_PLATFORMS)
ANDROID_RELEASE_APK := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).apk
ANDROID_RELEASE_AAB := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).aab
ANDROID_STEALTH_NOVPN_APK := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE))-stealth-novpn.apk
ANDROID_STEALTH_NOVPN_AAB := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE))-stealth-novpn.aab
ANDROID_MAPPING_SRC := build/app/outputs/mapping/release/mapping.txt
ANDROID_SYMBOLS_SRC := build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip
PYTHON ?= python3
STEALTH_LEAKAGE_MODE ?= stealth
STEALTH_LEAKAGE_CONFIG ?= scripts/stealth/forbidden_tokens.json
STEALTH_LEAKAGE_PATHS ?= $(ANDROID_RELEASE_APK) $(ANDROID_RELEASE_AAB) $(ANDROID_APK_RELEASE_BUILD) $(ANDROID_AAB_RELEASE_BUILD)
STEALTH_LEAKAGE_MISSING_OK ?= 1
ANDROID_NDK_VERSION          ?= 28.2.13676358
ANDROID_CMAKE_VERSION        ?= 3.31.5
ANDROID_BUILD_TOOLS_VERSION  ?= 35.0.0
ANDROID_PLATFORM             ?= android-36
ANDROID_SDK_ROOT             := $(or $(ANDROID_SDK_ROOT),$(ANDROID_HOME))
SDKMANAGER                   := $(ANDROID_SDK_ROOT)/cmdline-tools/latest/bin/sdkmanager
ANDROID_DEBUG_FLUTTER_FLAGS  ?= --verbose
ANDROID_PAGE_SIZE ?= 16384
# Android 15+ Play requirement: arm64 native libs must be linked for 16 KB page-size compatibility.
ANDROID_GOMOBILE_LDFLAGS ?= -s -w -checklinkname=0 -extldflags=-Wl,-z,max-page-size=$(ANDROID_PAGE_SIZE),-z,common-page-size=$(ANDROID_PAGE_SIZE)
ANDROID_STEALTH_IDENTITY ?= $(if $(strip $(filter stealth stealth-%,$(BUILD_TYPE))$(STEALTH_MODE)$(STEALTH_PROFILE)),1,0)
ANDROID_GENERATE_IDENTITY_PROFILE ?= $(ANDROID_STEALTH_IDENTITY)
ANDROID_GENERATED_IDENTITY_PROFILE := $(BUILD_DIR)/stealth/android-identity.properties
ANDROID_IDENTITY_PROFILE ?= $(if $(filter 1 true yes,$(ANDROID_GENERATE_IDENTITY_PROFILE)),$(ANDROID_GENERATED_IDENTITY_PROFILE),)
ANDROID_IDENTITY_ENV = $(if $(strip $(ANDROID_IDENTITY_PROFILE)),ANDROID_IDENTITY_PROFILE="$(abspath $(ANDROID_IDENTITY_PROFILE))",)
ANDROID_AUTH_SCHEME = $(strip $(if $(ANDROID_IDENTITY_PROFILE),$(shell sed -n 's/^appAuthScheme=//p' "$(ANDROID_IDENTITY_PROFILE)" 2>/dev/null | tail -n 1),))
ANDROID_IDENTITY_DART_DEFINES = $(if $(STEALTH_ENABLED),,$(if $(ANDROID_AUTH_SCHEME),--dart-define=APP_AUTH_SCHEME=$(ANDROID_AUTH_SCHEME)))

IOS_INSTALLER := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).ipa
IOS_DIR := ios/
IOS_FRAMEWORK := Liblantern.xcframework
IOS_FRAMEWORK_DIR := ios/Frameworks
IOS_FRAMEWORK_BUILD := $(BIN_DIR)/ios/$(IOS_FRAMEWORK)
IOS_DEBUG_BUILD := $(BUILD_DIR)/ios/iphoneos/Runner.app

TAGS=with_gvisor,with_quic,with_wireguard,with_utls,with_grpc,with_conntrack

WINDOWS_CGO_LDFLAGS=-static-libgcc -static-libstdc++ -static -lwinpthread

ifeq ($(OS),Windows_NT)
GO_VERSION ?= $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command '$$line=(Select-String -Path "go.mod" -Pattern "^go\s+(.+)$$").Matches[0].Groups[1].Value.Trim(); Write-Output ("go"+$$line)')
GO_SOURCES := go.mod go.sum
UNAME_S := Windows
else
GO_VERSION ?= $(shell grep '^go ' go.mod | awk '{print "go" $$2}')
GO_SOURCES := go.mod go.sum $(shell find . -type f -name '*.go')
UNAME_S := $(shell uname -s)
endif
GOMOBILECACHE ?= $(HOME)/.cache/gomobile
# gomobile bind produces the AAR consumed by both the APK and the AAB.
# arm64 only — armeabi-v7a (32-bit) is no longer shipped in any artifact
# (golang/go#70495 SIGSYS on 32-bit Android 8-10).
GOMOBILE_ANDROID_TARGET ?= android/arm64
GOMOBILE_VERSION ?= latest
GOMOBILE_REPOS = \
	github.com/sagernet/sing-box/experimental/libbox \
	./lantern-core/mobile \
	./lantern-core/utils
# novpn now ships the FULL app over SOCKS (not the minimal proxy stub), so it
# binds the same packages as the regular/vpn build: libbox (sing-box, required by
# the real MainActivity's Libbox init + the SOCKS data path), mobile, utils.
GOMOBILE_REPOS_STEALTH_NOVPN = \
	github.com/sagernet/sing-box/experimental/libbox \
	./lantern-core/mobile \
	./lantern-core/utils

GARBLE ?= garble
GARBLE_VERSION ?= v0.16.0
GARBLE_SEED ?= $(STEALTH_GARBLE_SEED)
GARBLE_FLAGS ?= -literals
STEALTH_GOGARBLE_PACKAGES := github.com/getlantern/lantern,github.com/getlantern/radiance,github.com/getlantern/common,github.com/getlantern/lantern-box,github.com/getlantern/kindling,github.com/getlantern/netx,github.com/getlantern/flashlight,github.com/getlantern/golog,github.com/getlantern/sing-box-minimal,github.com/getlantern/amp,github.com/getlantern/broflake,github.com/getlantern/samizdat,github.com/getlantern/domainfront,github.com/getlantern/semconv,github.com/getlantern/publicip,github.com/getlantern/dnstt,github.com/getlantern/keepcurrent,github.com/getlantern/algeneva,github.com/getlantern/lantern-water,github.com/getlantern/water,github.com/getlantern/wazero,github.com/getlantern/wireguard-go,github.com/getlantern/sing,github.com/getlantern/osversion,github.com/getlantern/timezone,github.com/getlantern/pluriconfig,github.com/getlantern/appdir,github.com/getlantern/context,github.com/getlantern/fronted,github.com/getlantern/lantern-server-provisioner,github.com/getlantern/ops
GARBLE_GOGARBLE ?= $(if $(STEALTH_ENABLED),$(STEALTH_GOGARBLE_PACKAGES),github.com/getlantern/lantern)
GARBLE_LDFLAGS ?= -w -s -buildid=

ifeq ($(OS),Windows_NT)
GARBLE_REAL_GO ?= $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command '(Get-Command go -ErrorAction SilentlyContinue).Source')
GARBLE_ENV = $(if $(GARBLE_GOGARBLE),set GOGARBLE=$(GARBLE_GOGARBLE)&& ,set GOGARBLE=&& )
else
GARBLE_REAL_GO ?= $(shell command -v go 2>/dev/null)
GARBLE_ENV = $(if $(GARBLE_GOGARBLE),GOGARBLE="$(GARBLE_GOGARBLE)",env -u GOGARBLE)
endif
GARBLE_BUILD = $(GARBLE) $(GARBLE_FLAGS) -seed="$(GARBLE_SEED)" build

SIGN_ID="Developer ID Application: Brave New Software Project, Inc (ACZRKC3LQ9)"

get-command = $(shell which="$$(which $(1) 2> /dev/null)" && if [[ ! -z "$$which" ]]; then printf %q "$$which"; fi)
APPDMG    := $(call get-command,appdmg)

DART_DEFINES := --dart-define=BUILD_TYPE=$(BUILD_TYPE) $(if $(VERSION),--dart-define=VERSION=$(VERSION),)
STEALTH_NOVPN_BUILD_VARS := BUILD_TYPE=stealth-novpn STEALTH_MODE=stealth-novpn STEALTH_LEAKAGE_MODE=stealth-novpn
STEALTH_VPN_BUILD_VARS   := BUILD_TYPE=stealth-vpn  STEALTH_MODE=stealth-vpn  STEALTH_LEAKAGE_MODE=stealth-vpn
STEALTH_ICON_SEED ?=
STEALTH_ICON_RES_DIR ?= android/app/build/generated/icons/res
export STEALTH_ICON_SEED

STEALTH_PROFILE_SCRIPT := scripts/stealth/generate_profile.py
STEALTH_PROFILE_TOOL := $(PYTHON) $(STEALTH_PROFILE_SCRIPT)
STEALTH_FLUTTER_BUILD_SCRIPT := scripts/stealth/run_flutter_build.py
STEALTH_ANDROID_ARTIFACT_SANITIZER := scripts/stealth/sanitize_android_artifact.py
STEALTH_ANDROID_ARTIFACT_SIGNING_FLAGS := $(if $(filter 1 true yes,$(STEALTH_ALLOW_DEBUG_KEYSTORE)),--allow-debug-keystore,)
# De-branded copy of the REAL Android Kotlin + res, compiled in place of the
# legacy foundation.bridge stub source set so stealth ships the real native bridge.
STEALTH_DEBRAND_KOTLIN_SCRIPT := scripts/stealth/debrand_kotlin.py
STEALTH_ANDROID_GEN_DIR := $(BUILD_DIR)/stealth/android
STEALTH_ANDROID_KOTLIN_OUT := $(STEALTH_ANDROID_GEN_DIR)/kotlin
STEALTH_ANDROID_RES_OUT := $(STEALTH_ANDROID_GEN_DIR)/res
STEALTH_PROFILE ?=
STEALTH_MODE ?=
STEALTH_PACKAGE_NAME ?=
STEALTH_APP_NAME ?=
STEALTH_SESSION_NAME ?=
STEALTH_OBFUSCATION_SEED ?=
STEALTH_GO_OBFUSCATION_SEED ?= $(STEALTH_OBFUSCATION_SEED)
STEALTH_DENYLIST_VERSION ?=
STEALTH_PROFILE_OUT ?= $(BUILD_DIR)/stealth/profile.json
STEALTH_DART_DEFINES_FILE ?= $(BUILD_DIR)/stealth/dart-defines.json
STEALTH_ARTIFACT_METADATA ?= $(BUILD_DIR)/stealth/artifact-metadata.json
STEALTH_GO_TAGS_FILE ?= $(BUILD_DIR)/stealth/go-tags-suffix.txt
STEALTH_PROFILE_STAMP ?= $(BUILD_DIR)/stealth/profile.stamp
STEALTH_PROFILE_INPUTS_FILE ?= $(BUILD_DIR)/stealth/profile.inputs
STEALTH_ENABLED := $(strip $(STEALTH_MODE)$(STEALTH_PROFILE))
STEALTH_DART_DEFINES := $(if $(STEALTH_ENABLED),--dart-define-from-file=$(STEALTH_DART_DEFINES_FILE),)
STEALTH_GO_TAGS = $(if $(STEALTH_ENABLED),$(if $(wildcard $(STEALTH_GO_TAGS_FILE)),$(strip $(file <$(STEALTH_GO_TAGS_FILE))),$(error missing $(STEALTH_GO_TAGS_FILE); run make stealth-profile before building)),)
STEALTH_PROFILE_ENV := $(if $(STEALTH_ENABLED),ORG_GRADLE_PROJECT_stealthProfile="$(abspath $(STEALTH_PROFILE_OUT))",)
MAYBE_STEALTH_PROFILE := $(if $(STEALTH_ENABLED),$(STEALTH_PROFILE_STAMP),)
STEALTH_IS_NOVPN = $(if $(findstring novpn,$(STEALTH_GO_TAGS)),1,)
GOMOBILE_REPOS_EFFECTIVE = $(if $(STEALTH_IS_NOVPN),$(GOMOBILE_REPOS_STEALTH_NOVPN),$(GOMOBILE_REPOS))
GOMOBILE_JAVAPKG = $(if $(STEALTH_ENABLED),foundation.engine,lantern.io)
STEALTH_FLUTTER_PREFIX = $(if $(STEALTH_ENABLED),$(PYTHON) $(STEALTH_FLUTTER_BUILD_SCRIPT) --profile "$(STEALTH_PROFILE_OUT)" --,)
# Stealth builds compile the REAL app entrypoint (lib/main.dart, Flutter's
# default target). De-branding is a pre-compile transform (run_flutter_build.py)
# plus the AppBuildInfo dart-define guards; the legacy lib/main_stealth.dart stub
# is no longer used.
STEALTH_FLUTTER_TARGET =
# Dart symbol obfuscation removes brand *identifiers* (e.g. LanternService) from
# the AOT-compiled libapp.so. Applied to stealth release builds only; requires
# --split-debug-info. The symbol map stays local and is NOT shipped in the APK.
STEALTH_FLUTTER_OBFUSCATE = $(if $(STEALTH_ENABLED),--obfuscate --split-debug-info=$(BUILD_DIR)/stealth/debug-symbols,)
FLUTTER_DART_DEFINES = $(if $(STEALTH_ENABLED),$(if $(VERSION),--dart-define=VERSION=$(VERSION),),$(DART_DEFINES))

INSTALLER_RESOURCES := installer-resources

# Missing and Guards
guard-%:
	 @ if [ -z '${${*}}' ]; then echo 'Environment  $* variable not set' && exit 1; fi

check-gomobile:
	@command -v gomobile >/dev/null || (echo "gomobile not found. Run 'make install-android-deps'" && exit 1)

.PHONY: stealth-android-sources
stealth-android-sources:
	$(PYTHON) $(STEALTH_DEBRAND_KOTLIN_SCRIPT) \
	  --output $(STEALTH_ANDROID_KOTLIN_OUT) \
	  --res-source android/app/src/main/res \
	  --res-overlay android/app/src/stealth/res \
	  --res-output $(STEALTH_ANDROID_RES_OUT)

.PHONY: stealth-profile FORCE
stealth-profile:
	$(MAKE) -B "$(STEALTH_PROFILE_STAMP)"

$(STEALTH_PROFILE_STAMP): FORCE $(STEALTH_PROFILE_SCRIPT)
	$(call MKDIR_P,$(dir $(STEALTH_PROFILE_STAMP)))
	@set -e; { \
	  printf 'STEALTH_PROFILE_SCRIPT_SHA256='; \
	  $(PYTHON) -c 'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$(STEALTH_PROFILE_SCRIPT)"; \
	  printf 'STEALTH_PROFILE=%s\n' "$(STEALTH_PROFILE)"; \
	  printf 'STEALTH_PROFILE_SHA256='; \
	  if [ -n "$(STEALTH_PROFILE)" ] && [ -f "$(STEALTH_PROFILE)" ]; then \
	    $(PYTHON) -c 'import hashlib, pathlib, sys; print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' "$(STEALTH_PROFILE)"; \
	  else \
	    printf '\n'; \
	  fi; \
	  printf 'STEALTH_MODE=%s\n' "$(STEALTH_MODE)"; \
	  printf 'STEALTH_PACKAGE_NAME=%s\n' "$(STEALTH_PACKAGE_NAME)"; \
	  printf 'STEALTH_APP_NAME=%s\n' "$(STEALTH_APP_NAME)"; \
	  printf 'STEALTH_SESSION_NAME=%s\n' "$(STEALTH_SESSION_NAME)"; \
	  printf 'STEALTH_GO_OBFUSCATION_SEED_SHA256='; \
	  if [ -n "$(STEALTH_GO_OBFUSCATION_SEED)" ]; then \
	    $(PYTHON) -c 'import hashlib, sys; print(hashlib.sha256(sys.argv[1].encode("utf-8")).hexdigest())' "$(STEALTH_GO_OBFUSCATION_SEED)"; \
	  else \
	    printf '\n'; \
	  fi; \
	  printf 'STEALTH_DENYLIST_VERSION=%s\n' "$(STEALTH_DENYLIST_VERSION)"; \
	} > "$(STEALTH_PROFILE_INPUTS_FILE).tmp"
	@set -e; \
	tmp_profile="$(STEALTH_PROFILE_OUT).tmp"; \
	tmp_dart_defines="$(STEALTH_DART_DEFINES_FILE).tmp"; \
	tmp_artifact_metadata="$(STEALTH_ARTIFACT_METADATA).tmp"; \
	tmp_go_tags="$(STEALTH_GO_TAGS_FILE).tmp"; \
	trap 'rm -f "$(STEALTH_PROFILE_INPUTS_FILE).tmp" "$$tmp_profile" "$$tmp_dart_defines" "$$tmp_artifact_metadata" "$$tmp_go_tags"' EXIT; \
	if test -f "$(STEALTH_PROFILE_INPUTS_FILE)" && \
		cmp -s "$(STEALTH_PROFILE_INPUTS_FILE).tmp" "$(STEALTH_PROFILE_INPUTS_FILE)" && \
		test -s "$(STEALTH_PROFILE_OUT)" && \
		test -s "$(STEALTH_DART_DEFINES_FILE)" && \
		test -s "$(STEALTH_ARTIFACT_METADATA)" && \
		test -s "$(STEALTH_GO_TAGS_FILE)"; then \
	  touch "$@"; \
	  rm -f "$(STEALTH_PROFILE_INPUTS_FILE).tmp"; \
	else \
	  $(STEALTH_PROFILE_TOOL) \
		$(if $(STEALTH_PROFILE),--input "$(STEALTH_PROFILE)",) \
		$(if $(STEALTH_MODE),--mode "$(STEALTH_MODE)",) \
		$(if $(STEALTH_PACKAGE_NAME),--package-name "$(STEALTH_PACKAGE_NAME)",) \
		$(if $(STEALTH_APP_NAME),--app-name "$(STEALTH_APP_NAME)",) \
		$(if $(STEALTH_SESSION_NAME),--session-name "$(STEALTH_SESSION_NAME)",) \
		$(if $(STEALTH_GO_OBFUSCATION_SEED),--go-obfuscation-seed "$(STEALTH_GO_OBFUSCATION_SEED)",) \
		$(if $(STEALTH_DENYLIST_VERSION),--denylist-version "$(STEALTH_DENYLIST_VERSION)",) \
		--output "$$tmp_profile" \
		--dart-defines-output "$$tmp_dart_defines" \
		--artifact-metadata-output "$$tmp_artifact_metadata"; \
	  $(STEALTH_PROFILE_TOOL) --input "$$tmp_profile" --go-tags-suffix > "$$tmp_go_tags"; \
	  mv "$(STEALTH_PROFILE_INPUTS_FILE).tmp" "$(STEALTH_PROFILE_INPUTS_FILE)"; \
	  mv "$$tmp_profile" "$(STEALTH_PROFILE_OUT)"; \
	  mv "$$tmp_dart_defines" "$(STEALTH_DART_DEFINES_FILE)"; \
	  mv "$$tmp_artifact_metadata" "$(STEALTH_ARTIFACT_METADATA)"; \
	  mv "$$tmp_go_tags" "$(STEALTH_GO_TAGS_FILE)"; \
	  touch "$@"; \
	fi

.PHONY: check-garble require-garble-seed check-garble-seed check-garble-go
check-garble:
	@command -v $(GARBLE) >/dev/null 2>&1 || \
		{ echo "garble not found. Run 'make install-garble' or set GARBLE=/path/to/garble."; exit 1; }
	@command -v git >/dev/null 2>&1 || \
		{ echo "git not found. garble requires git to patch the Go linker."; exit 1; }
	@$(GARBLE) -h >/dev/null 2>&1 || \
		{ echo "garble was found but could not run. Check GARBLE=$(GARBLE) and your Go toolchain."; exit 1; }

require-garble-seed:
	@if [ -z "$(GARBLE_SEED)" ]; then \
		echo "GARBLE_SEED is required for obfuscated builds."; \
		echo "Set GARBLE_SEED=<base64 profile seed> or STEALTH_GARBLE_SEED=<base64 profile seed>."; \
		echo "Use GARBLE_SEED=random only for unreproducible local smoke builds."; \
		exit 1; \
	fi

check-garble-seed: check-garble require-garble-seed
	@$(GARBLE) -seed="$(GARBLE_SEED)" version >/dev/null 2>&1 || \
		{ echo "GARBLE_SEED must be 'random' or a base64-encoded seed accepted by garble."; exit 1; }

check-garble-go:
	@if [ -z "$(GARBLE_REAL_GO)" ]; then \
		echo "go not found. Install Go or set GARBLE_REAL_GO=/path/to/go for gomobile garble builds."; \
		exit 1; \
	fi

.PHONY: stealth-android-icons
stealth-android-icons: guard-STEALTH_ICON_SEED
	$(PYTHON) scripts/stealth/generate_android_icons.py \
		--output-res-dir "$(STEALTH_ICON_RES_DIR)"


.PHONY: require-appdmg
require-appdmg:
	@if [[ -z "$(APPDMG)" ]]; then echo 'Missing "appdmg" command. Try sudo npm install -g appdmg.'; exit 1; fi

.PHONY: require-ac-username
require-ac-username: guard-AC_USERNAME ## App Store Connect username - needed for notarizing macOS apps.

.PHONY: require-ac-password
require-ac-password: guard-AC_PASSWORD ## App Store Connect password - needed for notarizing macOS apps.

ifeq ($(OS),Windows_NT)
  NORMALIZED_CURDIR := $(subst \,/,$(CURDIR))
  SETENV = set CGO_ENABLED=1&& set CGO_CFLAGS=-I$(NORMALIZED_CURDIR)/dart_api_dl/include&& set CGO_LDFLAGS=$(WINDOWS_CGO_LDFLAGS)&&
else
  SETENV = CGO_ENABLED=1 CGO_CFLAGS=-I$(CURDIR)/dart_api_dl/include
endif

.PHONY: desktop-lib
desktop-lib: $(MAYBE_STEALTH_PROFILE)
	$(SETENV) go build -v -trimpath -buildmode=c-shared \
		-tags="$(TAGS)$(STEALTH_GO_TAGS)" \
		-ldflags="-w -s $(GO_EXTRA_LDFLAGS)" \
		-o $(LIB_NAME) ./$(FFI_DIR)
	@echo "Built desktop library: $(LIB_NAME)"

.PHONY: desktop-lib-obfuscated
desktop-lib-obfuscated: check-garble-seed
	$(call MKDIR_P,$(dir $(LIB_NAME)))
	@$(SETENV) $(GARBLE_ENV) $(GARBLE_BUILD) -v -trimpath -buildmode=c-shared \
		-tags="$(TAGS)" \
		-ldflags="$(GARBLE_LDFLAGS) $(EXTRA_LDFLAGS)" \
		-o $(LIB_NAME) ./$(FFI_DIR)
	@echo "Built obfuscated desktop library: $(LIB_NAME)"

# macOS build tools need to be installed when generating release builds,
# but are not necessarily required for debug builds
.PHONY: install-macos-deps

install-macos-deps: install-gomobile
	npm install -g appdmg
	brew tap joshdk/tap
	brew install joshdk/tap/retry
	brew install imagemagick || true

.PHONY: macos
macos: $(MACOS_FRAMEWORK_OUTPUT)

$(MACOS_FRAMEWORK_OUTPUT): $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	@echo "Building macOS Framework.."
	rm -rf $(MACOS_FRAMEWORK_BUILD) $@ && mkdir -p $(MACOS_FRAMEWORK_DIR)
	GOTOOLCHAIN=$(GO_VERSION) GOOS=darwin gomobile bind -v \
		-tags=$(TAGS),netgo$(STEALTH_GO_TAGS)  -trimpath \
		-target=macos \
		-o $(MACOS_FRAMEWORK_BUILD) \
		-ldflags="-w -s -checklinkname=0 $(GO_EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS)
	mv $(MACOS_FRAMEWORK_BUILD) $@
	@echo "Built macOS Framework: $@"


.PHONY: macos-framework
macos-framework: $(MACOS_FRAMEWORK_OUTPUT)

.PHONY: macos-debug
macos-debug: $(DARWIN_DEBUG_BUILD)

$(DARWIN_DEBUG_BUILD): $(DARWIN_LIB_BUILD) $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (debug) for macOS..."
	flutter build macos --debug $(DART_DEFINES) $(STEALTH_DART_DEFINES)

.PHONY: macos-unit-tests
macos-unit-tests: $(MACOS_FRAMEWORK_OUTPUT) $(MAYBE_STEALTH_PROFILE)
	@echo "Preparing macOS test project (building native assets)..."
	CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
		flutter build macos --debug --config-only $(DART_DEFINES) $(STEALTH_DART_DEFINES)
	@echo "Running macOS Runner unit tests..."
	xcodebuild test \
		-workspace macos/Runner.xcworkspace \
		-scheme Runner \
		-configuration Debug \
		-destination "platform=macOS" \
		-only-testing:RunnerTests \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY=""

$(DARWIN_RELEASE_BUILD): $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (release) for macOS..."
	rm -vf $(MACOS_INSTALLER)
	flutter build macos --release $(DART_DEFINES) $(STEALTH_DART_DEFINES)

build-macos-release: $(DARWIN_RELEASE_BUILD)

.PHONY: notarize-darwin
notarize-darwin: require-ac-username require-ac-password
	@echo "Notarizing distribution package..."
	xcrun notarytool submit $(MACOS_INSTALLER) \
		--apple-id $$AC_USERNAME \
		--team-id "ACZRKC3LQ9" \
		--password $$AC_PASSWORD \
		--wait \
		--output-format json > notary_output.json
	@status=$$(jq -r '.status' notary_output.json); \
	if [ "$$status" != "Accepted" ]; then \
		id=$$(jq -r '.id' notary_output.json); \
		echo "Notarization failed with status $$status (submission $$id)" >&2; \
		xcrun notarytool log "$$id" \
			--apple-id $$AC_USERNAME \
			--team-id "ACZRKC3LQ9" \
			--password $$AC_PASSWORD || true; \
		exit 1; \
	fi
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(MACOS_INSTALLER)
	@echo "Notarization complete"


.PHONY: notarize-log
notarize-log:
	xcrun notarytool log 3036c6b2-8f99-44d7-8c3e-6c9c007b2524 \
		--apple-id $$AC_USERNAME \
		--team-id "ACZRKC3LQ9" \
		--password $$AC_PASSWORD \
		--output-format json > notary_log.json
sign-app:
	scripts/ci/sign_macos_app.sh \
		$(DARWIN_RELEASE_BUILD) \
		$(SIGN_ID) \
		$(MACOS_ENTITLEMENTS) \
		$(PACKET_ENTITLEMENTS)

package-macos: require-appdmg
	appdmg appdmg.json $(MACOS_INSTALLER)

.PHONY: macos-release
macos-release: clean macos pubget gen build-macos-release sign-app package-macos notarize-darwin

.PHONY: macos-release-ci
macos-release-ci: macos pubget gen build-macos-release sign-app package-macos notarize-darwin

# Linux Build
.PHONY: install-linux-deps

install-linux-deps:
	@command -v nfpm >/dev/null 2>&1 || \
		{ echo "Installing nfpm..."; go install github.com/goreleaser/nfpm/v2/cmd/nfpm@v2.45.0; }

.PHONY: linux-arm64
linux-arm64: $(LINUX_LIB_ARM64)

$(LINUX_LIB_ARM64): $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	CC=$(LINUX_CC_ARM64) GOOS=linux GOARCH=arm64 LIB_NAME=$@ $(MAKE) desktop-lib

.PHONY: linux-arm64-obfuscated
linux-arm64-obfuscated: $(GO_SOURCES)
	CC=$(LINUX_CC_ARM64) GOOS=linux GOARCH=arm64 LIB_NAME=$(LINUX_LIB_ARM64) $(MAKE) desktop-lib-obfuscated

.PHONY: linux-amd64
linux-amd64: $(LINUX_LIB_AMD64)

$(LINUX_LIB_AMD64): $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	CC=$(LINUX_CC_AMD64) GOOS=linux GOARCH=amd64 LIB_NAME=$@ $(MAKE) desktop-lib

.PHONY: linux-amd64-obfuscated
linux-amd64-obfuscated: $(GO_SOURCES)
	CC=$(LINUX_CC_AMD64) GOOS=linux GOARCH=amd64 LIB_NAME=$(LINUX_LIB_AMD64) $(MAKE) desktop-lib-obfuscated

.PHONY: linux
linux: linux-$(LINUX_TARGET_ARCH)
	mkdir -p $(BIN_DIR)/linux
	cp $(BIN_DIR)/linux-$(LINUX_TARGET_ARCH)/$(LINUX_LIB) $(LINUX_LIB_BUILD)

.PHONY: linux-obfuscated
linux-obfuscated: linux-$(LINUX_TARGET_ARCH)-obfuscated
	mkdir -p $(BIN_DIR)/linux
	cp $(BIN_DIR)/linux-$(LINUX_TARGET_ARCH)/$(LINUX_LIB) $(LINUX_LIB_BUILD)

.PHONY: lanternd-linux-amd64 lanternd-linux-arm64 \
        lanternd-linux-amd64-obfuscated lanternd-linux-arm64-obfuscated

lanternd-linux-amd64: $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(LANTERND_LINUX_AMD64)))
	GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
		go build -mod=mod -v -trimpath -tags "$(TAGS)$(STEALTH_GO_TAGS)" \
		-ldflags "-w -s $(LANTERND_EXTRA_LDFLAGS)" \
		-o $(LANTERND_LINUX_AMD64) $(LANTERND_SRC)
	@echo "Built lanternd (linux-amd64): $(LANTERND_LINUX_AMD64)"

lanternd-linux-arm64: $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(LANTERND_LINUX_ARM64)))
	GOOS=linux GOARCH=arm64 CGO_ENABLED=1 \
		go build -mod=mod -v -trimpath -tags "$(TAGS)$(STEALTH_GO_TAGS)" \
		-ldflags "-w -s $(LANTERND_EXTRA_LDFLAGS)" \
		-o $(LANTERND_LINUX_ARM64) $(LANTERND_SRC)
	@echo "Built lanternd (linux-arm64): $(LANTERND_LINUX_ARM64)"

lanternd-linux-amd64-obfuscated: check-garble-seed $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(LANTERND_LINUX_AMD64)))
	@$(GARBLE_ENV) GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
		$(GARBLE_BUILD) -mod=mod -v -trimpath -tags "$(TAGS)" \
		-ldflags "$(GARBLE_LDFLAGS) $(EXTRA_LDFLAGS)" \
		-o $(LANTERND_LINUX_AMD64) $(LANTERND_SRC)
	@echo "Built obfuscated lanternd (linux-amd64): $(LANTERND_LINUX_AMD64)"

lanternd-linux-arm64-obfuscated: check-garble-seed $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(LANTERND_LINUX_ARM64)))
	@$(GARBLE_ENV) GOOS=linux GOARCH=arm64 CGO_ENABLED=1 \
		$(GARBLE_BUILD) -mod=mod -v -trimpath -tags "$(TAGS)" \
		-ldflags "$(GARBLE_LDFLAGS) $(EXTRA_LDFLAGS)" \
		-o $(LANTERND_LINUX_ARM64) $(LANTERND_SRC)
	@echo "Built obfuscated lanternd (linux-arm64): $(LANTERND_LINUX_ARM64)"

.PHONY: linux-debug
linux-debug: $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (debug) for Linux..."
	flutter build linux --debug $(DART_DEFINES) $(STEALTH_DART_DEFINES)

.PHONY: linux-release linux-release-ci
linux-release: clean linux-release-ci

linux-release-ci: linux pubget gen $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (release) for Linux..."
	flutter build linux --release $(DART_DEFINES) $(STEALTH_DART_DEFINES)
	$(MAKE) lanternd-linux-$(LINUX_TARGET_ARCH)

	@if [ "$(LINUX_TARGET_ARCH)" = "arm64" ]; then \
	  BUNDLE_DIR="$(LINUX_BUNDLE_DIR_ARM64)"; \
	else \
	  BUNDLE_DIR="$(LINUX_BUNDLE_DIR_X64)"; \
	fi; \
	if [ ! -d "$$BUNDLE_DIR" ]; then \
	  echo "Expected Linux bundle dir not found: $$BUNDLE_DIR"; \
	  exit 1; \
	fi; \
	echo "Using Linux bundle dir: $$BUNDLE_DIR"; \
	cp "$(LINUX_LIB_BUILD)" "$$BUNDLE_DIR"; \
	cp "$(BIN_DIR)/linux-$(LINUX_TARGET_ARCH)/$(LANTERND)" "$$BUNDLE_DIR"; \
	printf '%s\n' "$(LANTERND_SERVICE_LOG_LEVEL)" > "$$BUNDLE_DIR/lanternd-log-level"; \
	patchelf --set-rpath '$$ORIGIN/lib' "$$BUNDLE_DIR/lantern" || true; \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p deb -t $(LINUX_INSTALLER_DEB); \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p rpm -t $(LINUX_INSTALLER_RPM); \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p archlinux -t $(LINUX_INSTALLER_ARCH)

.PHONY: verify-linux-package
verify-linux-package:
	./scripts/ci/verify_linux_package.sh $(LINUX_INSTALLER_DEB)

# Windows Build
.PHONY: lanternd-windows-amd64 lanternd-windows-arm64 \
        copy-lanternd-release copy-lanternd-release-arm64 copy-lanternd-debug

.PHONY: install-windows-deps
install-windows-deps:
	dart pub global activate fastforge

windows: windows-amd64
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_BUILD)))
	$(call COPY_FILE,$(WINDOWS_LIB_AMD64),$(WINDOWS_LIB_BUILD))

windows-amd64: WINDOWS_GOOS := windows
windows-amd64: WINDOWS_GOARCH := amd64
windows-amd64: $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_AMD64)))
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_AMD64) CGO_LDFLAGS="$(WINDOWS_CGO_LDFLAGS)"
windows-arm64: WINDOWS_GOOS := windows
windows-arm64: WINDOWS_GOARCH := arm64
windows-arm64: $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_ARM64)))
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_ARM64) CGO_LDFLAGS="$(WINDOWS_CGO_LDFLAGS)"

lanternd-windows-amd64: $(LANTERND_WINDOWS_AMD64)

lanternd-windows-arm64: $(LANTERND_WINDOWS_ARM64)

$(LANTERND_WINDOWS_AMD64): $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(LANTERND_WINDOWS_AMD64)))
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
		go build -mod=mod -v -trimpath -tags "$(TAGS)$(STEALTH_GO_TAGS)" \
		-ldflags "$(LANTERND_EXTRA_LDFLAGS)" \
		-o $(LANTERND_WINDOWS_AMD64) $(LANTERND_SRC)
	@echo "Built lanternd (windows-amd64): $(LANTERND_WINDOWS_AMD64)"

$(LANTERND_WINDOWS_ARM64): $(MAYBE_STEALTH_PROFILE)
	$(call MKDIR_P,$(dir $(LANTERND_WINDOWS_ARM64)))
	GOOS=windows GOARCH=arm64 CGO_ENABLED=0 \
		go build -mod=mod -v -trimpath -tags "$(TAGS)$(STEALTH_GO_TAGS)" \
		-ldflags "$(LANTERND_EXTRA_LDFLAGS)" \
		-o $(LANTERND_WINDOWS_ARM64) $(LANTERND_SRC)
	@echo "Built lanternd (windows-arm64): $(LANTERND_WINDOWS_ARM64)"

copy-lanternd-release: $(LANTERND_WINDOWS_AMD64)
	$(call MKDIR_P,$(WINDOWS_RELEASE_DIR))
	$(call COPY_FILE,$(LANTERND_WINDOWS_AMD64),$(LANTERND_WINDOWS_RELEASE))

copy-lanternd-release-arm64: $(LANTERND_WINDOWS_ARM64)
	$(call MKDIR_P,$(dir $(LANTERND_WINDOWS_RELEASE_ARM64)))
	$(call COPY_FILE,$(LANTERND_WINDOWS_ARM64),$(LANTERND_WINDOWS_RELEASE_ARM64))

copy-lanternd-debug: $(LANTERND_WINDOWS_AMD64)
	$(call MKDIR_P,$(WINDOWS_DEBUG_DIR))
	$(call COPY_FILE,$(LANTERND_WINDOWS_AMD64),$(WINDOWS_DEBUG_DIR)/$(LANTERND).exe)

.PHONY: prepare-windows-release
prepare-windows-release: lanternd-windows-amd64 lanternd-windows-arm64
	$(MAKE) copy-lanternd-release
	$(MAKE) copy-lanternd-release-arm64
	$(call WRITE_TEXT_FILE,$(LANTERND_SERVICE_LOG_LEVEL),$(WINDOWS_RELEASE_DIR)/lanternd-log-level)

.PHONY: windows-debug
windows-debug: windows $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (debug) for Windows..."
	flutter build windows --debug $(DART_DEFINES) $(STEALTH_DART_DEFINES)

.PHONY: build-windows-release
build-windows-release: $(MAYBE_STEALTH_PROFILE)
	@echo "Building Flutter app (release) for Windows..."
	flutter build windows --release --verbose $(DART_DEFINES) $(STEALTH_DART_DEFINES)

.PHONY: windows-release
windows-release: clean windows pubget gen build-windows-release prepare-windows-release

.PHONY: install-gomobile
install-gomobile:
	GOTOOLCHAIN=$(GO_VERSION) go install -v golang.org/x/mobile/cmd/gomobile@$(GOMOBILE_VERSION)
	GOTOOLCHAIN=$(GO_VERSION) go install -v golang.org/x/mobile/cmd/gobind@$(GOMOBILE_VERSION)
	@mkdir -p "$(GOMOBILECACHE)"
	@if [ ! -f "$(GOMOBILECACHE)/.init-$(GO_VERSION)" ]; then \
		echo "Running gomobile init (first time for $(GO_VERSION))..."; \
		GOMOBILECACHE="$(GOMOBILECACHE)" GOTOOLCHAIN=$(GO_VERSION) gomobile init; \
		touch "$(GOMOBILECACHE)/.init-$(GO_VERSION)"; \
	else \
		echo "Skipping gomobile init (cached for $(GO_VERSION))"; \
	fi

.PHONY: install-garble
install-garble:
	GOTOOLCHAIN=$(GO_VERSION) go install -v mvdan.cc/garble@$(GARBLE_VERSION)

# Android Build
.PHONY: check-android-sdk
check-android-sdk:
ifeq ($(ANDROID_SDK_ROOT),)
	$(error ANDROID_SDK_ROOT or ANDROID_HOME must be set. Export the path to your Android SDK directory.)
endif

.PHONY: install-android-sdk
install-android-sdk: check-android-sdk
	$(SDKMANAGER) \
		"platform-tools" \
		"platforms;$(ANDROID_PLATFORM)" \
		"build-tools;$(ANDROID_BUILD_TOOLS_VERSION)" \
		"ndk;$(ANDROID_NDK_VERSION)" \
		"cmake;$(ANDROID_CMAKE_VERSION)"
	yes | $(SDKMANAGER) --licenses > /dev/null || true

.PHONY: android-env
android-env: check-android-sdk
	@echo "ANDROID_HOME=$(ANDROID_SDK_ROOT)"
	@echo "ANDROID_NDK_HOME=$(ANDROID_SDK_ROOT)/ndk/$(ANDROID_NDK_VERSION)"
	@echo "ANDROID_NDK_ROOT=$(ANDROID_SDK_ROOT)/ndk/$(ANDROID_NDK_VERSION)"
	@echo "NDK_HOME=$(ANDROID_SDK_ROOT)/ndk/$(ANDROID_NDK_VERSION)"

.PHONY: install-android-deps
install-android-deps: install-gomobile

.PHONY: android-identity-profile
android-identity-profile: $(MAYBE_STEALTH_PROFILE)
	@if [ "$(ANDROID_GENERATE_IDENTITY_PROFILE)" = "1" ] || [ "$(ANDROID_GENERATE_IDENTITY_PROFILE)" = "true" ] || [ "$(ANDROID_GENERATE_IDENTITY_PROFILE)" = "yes" ]; then \
	  if [ -z "$(ANDROID_IDENTITY_PROFILE)" ]; then \
	    echo "ANDROID_IDENTITY_PROFILE is empty"; \
	    exit 1; \
	  fi; \
		  if [ ! -f "$(ANDROID_IDENTITY_PROFILE)" ] || [ -n "$(ANDROID_IDENTITY_SEED)" ] || [ "$(ANDROID_FORCE_IDENTITY_PROFILE)" = "1" ] || [ "$(ANDROID_FORCE_IDENTITY_PROFILE)" = "true" ] || [ "$(ANDROID_FORCE_IDENTITY_PROFILE)" = "yes" ]; then \
		    mkdir -p "$$(dirname "$(ANDROID_IDENTITY_PROFILE)")"; \
		    $(PYTHON) scripts/stealth/generate_android_identity.py \
		      --output "$(ANDROID_IDENTITY_PROFILE)" \
		      $(if $(STEALTH_ENABLED),--profile "$(STEALTH_PROFILE_OUT)",) \
		      $(if $(ANDROID_IDENTITY_SEED),--seed "$(ANDROID_IDENTITY_SEED)",); \
		  elif [ -n "$(STEALTH_ENABLED)" ]; then \
		    $(PYTHON) scripts/stealth/generate_android_identity.py \
		      --output "$(ANDROID_IDENTITY_PROFILE)" \
		      --profile "$(STEALTH_PROFILE_OUT)"; \
		  else \
		    echo "Using Android identity profile: $(ANDROID_IDENTITY_PROFILE)"; \
		  fi; \
	fi

.PHONY: android
android: check-android-sdk check-gomobile $(ANDROID_LIB_BUILD)

$(ANDROID_LIB_BUILD): $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	$(MAKE) build-android

build-android: check-android-sdk check-gomobile $(MAYBE_STEALTH_PROFILE)
	@echo "Building Android libraries..."
	rm -rf $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)
	mkdir -p $(dir $(ANDROID_LIB_BUILD)) $(ANDROID_LIBS_DIR)

	GOMOBILECACHE="$(GOMOBILECACHE)" \
	GOTOOLCHAIN=$(GO_VERSION) GOOS=android gomobile bind -v \
		-androidapi=23 \
		-target="$(GOMOBILE_ANDROID_TARGET)" \
		-javapkg=$(GOMOBILE_JAVAPKG) \
		-tags=$(TAGS)$(STEALTH_GO_TAGS) -trimpath \
		-o=$(ANDROID_LIB_BUILD) \
		-ldflags="$(ANDROID_GOMOBILE_LDFLAGS) $(GO_EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS_EFFECTIVE)

	cp $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)
	@echo "Built Android library: $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)"

.PHONY: android-obfuscated
android-obfuscated: build-android-obfuscated

.PHONY: build-android-obfuscated
build-android-obfuscated: check-android-sdk check-gomobile check-garble-seed check-garble-go $(MAYBE_STEALTH_PROFILE)
	@echo "Building obfuscated Android libraries..."
	rm -rf $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)
	mkdir -p $(dir $(ANDROID_LIB_BUILD)) $(ANDROID_LIBS_DIR)

	@PATH="$(CURDIR)/scripts/garble-go:$$PATH" \
	GARBLE_REAL_GO="$(GARBLE_REAL_GO)" \
	GARBLE_BIN="$(GARBLE)" \
	GARBLE_SEED="$(GARBLE_SEED)" \
	GARBLE_FLAGS="$(GARBLE_FLAGS)" \
	GARBLE_GOGARBLE="$(GARBLE_GOGARBLE)" \
	GOMOBILECACHE="$(GOMOBILECACHE)" \
	GOTOOLCHAIN=$(GO_VERSION) GOOS=android gomobile bind -v \
		-androidapi=23 \
		-target="$(GOMOBILE_ANDROID_TARGET)" \
		-javapkg=$(GOMOBILE_JAVAPKG) \
		-tags=$(TAGS)$(STEALTH_GO_TAGS) -trimpath \
		-o=$(ANDROID_LIB_BUILD) \
		-ldflags="$(ANDROID_GOMOBILE_LDFLAGS) $(GARBLE_LDFLAGS) $(EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS_EFFECTIVE)

	cp $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)
	@echo "Built obfuscated Android library: $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)"
	$(if $(STEALTH_ENABLED),$(MAKE) ANDROID_LIBS_DIR="$(ANDROID_LIBS_DIR)" ANDROID_LIB="$(ANDROID_LIB)" verify-stealth-jni,)

# verify-stealth-jni: hard gate on JNI symbol namespace in the stealth AAR.
# Extracts arm64-v8a/libgojni.so and asserts:
#   - Java_lantern_io_* is ABSENT (GOMOBILE_JAVAPKG=foundation.engine applied)
#   - Java_foundation_engine_* is PRESENT (gomobile binding succeeded)
# Called automatically by build-android-obfuscated when STEALTH_ENABLED is set.
# Can also be called standalone: make verify-stealth-jni
.PHONY: verify-stealth-jni
verify-stealth-jni:
	@echo "=== verify-stealth-jni: checking JNI namespace in $(ANDROID_LIBS_DIR)/$(ANDROID_LIB) ==="
	@tmpdir=$$(mktemp -d); \
	trap 'rm -rf "$$tmpdir"' EXIT; \
	aar="$(ANDROID_LIBS_DIR)/$(ANDROID_LIB)"; \
	if [ ! -f "$$aar" ]; then \
	  echo "FAIL: AAR not found at $$aar — build stealth AAR first"; \
	  exit 1; \
	fi; \
	unzip -q "$$aar" "jni/arm64-v8a/libgojni.so" -d "$$tmpdir" 2>/dev/null || \
	  { echo "FAIL: libgojni.so not found in $$aar (expected jni/arm64-v8a/libgojni.so)"; exit 1; }; \
	so="$$tmpdir/jni/arm64-v8a/libgojni.so"; \
	bad=$$(nm -D "$$so" 2>/dev/null | grep -c "Java_lantern_io" || true); \
	if [ "$$bad" -gt 0 ]; then \
	  echo "FAIL: $$bad Java_lantern_io_* symbol(s) found — GOMOBILE_JAVAPKG=foundation.engine not applied:"; \
	  nm -D "$$so" | grep "Java_lantern_io"; \
	  exit 1; \
	fi; \
	good=$$(nm -D "$$so" 2>/dev/null | grep -c "Java_foundation_engine" || true); \
	if [ "$$good" -eq 0 ]; then \
	  echo "FAIL: no Java_foundation_engine_* symbols found — gomobile javapkg binding is missing"; \
	  exit 1; \
	fi; \
	echo "PASS: JNI namespace gate — Java_lantern_io=0, Java_foundation_engine=$$good"

.PHONY: android-debug android-debug-ci
android-debug: $(ANDROID_DEBUG_BUILD)

android-debug-ci: ANDROID_DEBUG_FLUTTER_FLAGS :=
android-debug-ci: $(ANDROID_DEBUG_BUILD)

$(ANDROID_DEBUG_BUILD): $(ANDROID_LIB_BUILD) $(MAYBE_STEALTH_PROFILE)
	$(MAKE) android-identity-profile
	$(STEALTH_PROFILE_ENV) $(ANDROID_IDENTITY_ENV) $(STEALTH_FLUTTER_PREFIX) flutter build apk --target-platform $(ANDROID_APK_TARGET_PLATFORMS) $(ANDROID_DEBUG_FLUTTER_FLAGS) --build-name=$(APP_VERSION_PUBSPEC) --debug $(STEALTH_FLUTTER_TARGET) $(FLUTTER_DART_DEFINES) $(STEALTH_DART_DEFINES) $(ANDROID_IDENTITY_DART_DEFINES) -Plantern.sideloadUpdates=true

# Runs the Android integration test on a connected device (the FTL
# instrumentation path). Override the entrypoint with ANDROID_INTEGRATION_TARGET.
ANDROID_INTEGRATION_TARGET ?= integration_test/android_all_e2e_test.dart
ANDROID_INTEGRATION_DART_DEFINES ?=
# android/gradlew is gitignored, so CI overrides this with a runner-installed
# gradle (see .github/workflows/firebase-test-lab.yml).
ANDROID_GRADLE ?= ./gradlew

.PHONY: android-integration-test
android-integration-test: $(ANDROID_LIB_BUILD)
	@if [ -z "$$ANDROID_SERIAL" ]; then \
	  n=$$(adb devices | grep -c 'device$$'); \
	  if [ "$$n" != "1" ]; then \
	    echo "ERROR: $$n adb devices attached. connectedDebugAndroidTest runs on ALL of"; \
	    echo "them at once; if two are the SAME physical phone (USB + Wi-Fi, or duplicate"; \
	    echo "wireless-debugging transports) the concurrent instrumentation runs collide and"; \
	    echo "both report 'Process crashed'. Attach exactly one transport, or pin one with"; \
	    echo "ANDROID_SERIAL=<serial> (see 'adb devices -l')."; \
	    exit 1; \
	  fi; \
	fi
	@echo "Running Android integration test on connected device(s): $(ANDROID_INTEGRATION_TARGET)"
	cd android && $(ANDROID_GRADLE) app:connectedDebugAndroidTest -Ptarget=$(ANDROID_INTEGRATION_TARGET) $(ANDROID_INTEGRATION_DART_DEFINES)

# Builds the two APKs Firebase Test Lab needs to run the integration test as an
# instrumentation test — the app APK (with the Dart entrypoint baked in via
# -Ptarget) and the androidTest APK — without a connected device. Same default
# org.getlantern.lantern identity as android-integration-test (see above).
# Outputs:
#   build/app/outputs/apk/debug/app-debug.apk
#   build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
.PHONY: android-integration-apks
android-integration-apks: $(ANDROID_LIB_BUILD)
	@echo "Building integration test APKs (app + androidTest): $(ANDROID_INTEGRATION_TARGET)"
	cd android && $(ANDROID_GRADLE) app:assembleDebug app:assembleDebugAndroidTest -Ptarget=$(ANDROID_INTEGRATION_TARGET) $(ANDROID_INTEGRATION_DART_DEFINES)

# Runs the integration test APKs on Firebase Test Lab. Needs an authenticated
# gcloud CLI (`gcloud auth login`). Devices, project, bucket, etc. are
# overridable via FTL_* env vars — see scripts/android/ftl-run.sh.
.PHONY: android-ftl-test
android-ftl-test: android-integration-apks
	scripts/android/ftl-run.sh

# --target-platform restricts Flutter's libapp.so / libflutter.so to arm64.
# abiFilters is arm64-only for all artifacts now (no thinAbi flag needed).
# -Plantern.sideloadUpdates=true adds REQUEST_INSTALL_PACKAGES only to the
# direct-download APK artifact; Play AAB builds intentionally omit it.
.PHONY: android-apk-release
android-apk-release: android-identity-profile $(MAYBE_STEALTH_PROFILE)
	$(STEALTH_PROFILE_ENV) $(ANDROID_IDENTITY_ENV) $(STEALTH_FLUTTER_PREFIX) flutter build apk --target-platform $(ANDROID_APK_TARGET_PLATFORMS) --verbose --build-name=$(APP_VERSION_PUBSPEC) --release $(STEALTH_FLUTTER_TARGET) $(STEALTH_FLUTTER_OBFUSCATE) $(FLUTTER_DART_DEFINES) $(STEALTH_DART_DEFINES) $(ANDROID_IDENTITY_DART_DEFINES) -Plantern.sideloadUpdates=true
	$(if $(STEALTH_ENABLED),$(PYTHON) $(STEALTH_ANDROID_ARTIFACT_SANITIZER) --resign $(STEALTH_ANDROID_ARTIFACT_SIGNING_FLAGS) $(ANDROID_APK_RELEASE_BUILD),true)
	cp $(ANDROID_APK_RELEASE_BUILD) $(ANDROID_RELEASE_APK)

# AAB is arm64-only too (armeabi-v7a dropped — golang/go#70495 SIGSYS on
# 32-bit). 32-bit-only devices no longer get Play updates; they were
# crash-looping on Android 8-10 regardless.
.PHONY: android-aab-release
android-aab-release: android-identity-profile $(MAYBE_STEALTH_PROFILE)
	$(STEALTH_PROFILE_ENV) $(ANDROID_IDENTITY_ENV) $(STEALTH_FLUTTER_PREFIX) flutter build appbundle --target-platform $(ANDROID_AAB_TARGET_PLATFORMS) --verbose --build-name=$(APP_VERSION_PUBSPEC) --release $(STEALTH_FLUTTER_TARGET) $(STEALTH_FLUTTER_OBFUSCATE) $(FLUTTER_DART_DEFINES) $(STEALTH_DART_DEFINES) $(ANDROID_IDENTITY_DART_DEFINES)
	$(if $(STEALTH_ENABLED),$(PYTHON) $(STEALTH_ANDROID_ARTIFACT_SANITIZER) --resign $(STEALTH_ANDROID_ARTIFACT_SIGNING_FLAGS) $(ANDROID_AAB_RELEASE_BUILD),true)
	cp $(ANDROID_AAB_RELEASE_BUILD) $(ANDROID_RELEASE_AAB)
	$(MAKE) android-copy-play-artifacts

.PHONY: android-copy-play-artifacts
android-copy-play-artifacts:
ifneq ($(strip $(STEALTH_ENABLED)),)
	@echo "Skipping Play mapping and native symbols copy for stealth build"
else
	# Copy Play console artifacts
	@if [ -f "$(ANDROID_MAPPING_SRC)" ]; then \
	  cp "$(ANDROID_MAPPING_SRC)" mapping.txt; \
	fi

	@if [ -f "$(ANDROID_SYMBOLS_SRC)" ]; then \
	  cp "$(ANDROID_SYMBOLS_SRC)" debug-symbols.zip; \
	elif [ -d "build/app/intermediates/merged_native_libs/release/out/lib" ]; then \
	  (cd build/app/intermediates/merged_native_libs/release/out && zip -r ../../../../../../debug-symbols.zip lib >/dev/null); \
	fi
endif

.PHONY: android-stealth-novpn-apk-release
android-stealth-novpn-apk-release:
	$(MAKE) $(STEALTH_NOVPN_BUILD_VARS) stealth-android-sources android pubget gen android-apk-release

.PHONY: android-stealth-novpn-aab-release
android-stealth-novpn-aab-release:
	$(MAKE) $(STEALTH_NOVPN_BUILD_VARS) stealth-android-sources android pubget gen android-aab-release

.PHONY: android-stealth-novpn-release
android-stealth-novpn-release:
	$(MAKE) $(STEALTH_NOVPN_BUILD_VARS) stealth-android-sources android-release-ci

.PHONY: android-stealth-vpn-apk-release
android-stealth-vpn-apk-release:
	$(MAKE) $(STEALTH_VPN_BUILD_VARS) stealth-android-sources android pubget gen android-apk-release

.PHONY: android-stealth-vpn-aab-release
android-stealth-vpn-aab-release:
	$(MAKE) $(STEALTH_VPN_BUILD_VARS) stealth-android-sources android pubget gen android-aab-release

.PHONY: android-stealth-vpn-release
android-stealth-vpn-release:
	$(MAKE) $(STEALTH_VPN_BUILD_VARS) stealth-android-sources android-release-ci


.PHONY: android-release
android-release: clean android pubget gen android-identity-profile android-apk-release

.PHONY: android-release-ci
android-release-ci: android pubget gen android-identity-profile android-apk-release android-aab-release

.PHONY: stealth-leakage-check stealth-novpn-leakage-check
stealth-leakage-check:
	$(PYTHON) scripts/stealth/check_leakage.py \
		--config "$(STEALTH_LEAKAGE_CONFIG)" \
		--mode "$(STEALTH_LEAKAGE_MODE)" \
		$(if $(filter 1 true yes,$(STEALTH_LEAKAGE_MISSING_OK)),--missing-ok,) \
		$(STEALTH_LEAKAGE_PATHS)

stealth-novpn-leakage-check:
	$(MAKE) stealth-leakage-check STEALTH_LEAKAGE_MODE=stealth-novpn

.PHONY: android-release-obfuscated
android-release-obfuscated: clean android-obfuscated pubget gen android-identity-profile android-apk-release

.PHONY: android-release-ci-obfuscated
android-release-ci-obfuscated: android-obfuscated pubget gen android-identity-profile android-apk-release android-aab-release

.PHONY: stealth-manifest-filter-test
stealth-manifest-filter-test:
	$(PYTHON) -m unittest discover -s scripts/stealth -p '*_test.py'

# iOS Build
.PHONY: install-ios-deps

install-ios-deps: install-gomobile
	npm install -g appdmg

.PHONY: ios
ios: $(IOS_FRAMEWORK_BUILD)

.PHONY: ios
ios: check-gomobile $(IOS_FRAMEWORK_BUILD)

$(IOS_FRAMEWORK_BUILD): $(GO_SOURCES) $(MAYBE_STEALTH_PROFILE)
	$(MAKE) build-ios

build-ios: $(MAYBE_STEALTH_PROFILE)
	@echo "Building iOS Framework.."
	rm -rf $(IOS_FRAMEWORK_BUILD)
	rm -rf $(IOS_FRAMEWORK_DIR) && mkdir -p $(IOS_FRAMEWORK_DIR)
	GOOS=ios gomobile bind -v \
		-tags=$(TAGS),with_low_memory$(STEALTH_GO_TAGS) -trimpath \
		-target=ios \
		-o $(IOS_FRAMEWORK_BUILD) \
		-ldflags="-w -s -checklinkname=0 $(GO_EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS)
	@echo "Built iOS Framework: $(IOS_FRAMEWORK_BUILD)"
	mv $(IOS_FRAMEWORK_BUILD) $(IOS_FRAMEWORK_DIR)

.PHONY: format swift-format
swift-format:
	swift-format format --in-place --recursive ios/Runner ios/Tunnel ios/Shared macos/Runner macos/PacketTunnel macos/Shared

format:
	@echo "Formatting Dart code..."
	@dart format .
	@echo "Formatting go code"
	@cd lantern-core && go fmt ./...
	@echo "Formatting Swift code..."
	$(MAKE) swift-format

ios-release: clean pubget ios $(MAYBE_STEALTH_PROFILE)
	flutter build ipa --release --export-options-plist ./ExportOptions.plist $(DART_DEFINES) $(STEALTH_DART_DEFINES)
	@set -e; \
	  IPA_DIR="$(CURDIR)/build/ios/ipa"; \
	  IPA_SRC=$$(ls -t "$$IPA_DIR"/*.ipa 2>/dev/null | head -n 1); \
	  if [ -z "$$IPA_SRC" ]; then \
	    echo "ERROR: No .ipa found under $$IPA_DIR"; \
	    ls -la "$$IPA_DIR" || true; \
	    exit 1; \
	  fi; \
	  cp -f "$$IPA_SRC" "$(IOS_INSTALLER)"; \
	  echo "iOS IPA generated: $(IOS_INSTALLER)"

# Dart API DL bridge
DART_SDK_REPO=https://github.com/dart-lang/sdk
DART_SDK_INCLUDE_DIR=dart_api_dl/include
DART_SDK_BRANCH=main

.PHONY: update-dart-api-dl
update-dart-api-dl:
	@echo "Updating Dart API DL bridge..."
	rm -rf $(DART_SDK_INCLUDE_DIR)
	mkdir -p $(DART_SDK_INCLUDE_DIR)
	git clone --depth 1 --filter=blob:none --sparse $(DART_SDK_REPO) dart_sdk_tmp
	cd dart_sdk_tmp && git sparse-checkout set runtime/include
	mv dart_sdk_tmp/runtime/include/* $(DART_SDK_INCLUDE_DIR)/
	rm -rf dart_sdk_tmp
	@echo "Dart API DL bridge updated successfully!"


#Routes generation
gen:
	dart run build_runner build --delete-conflicting-outputs

# FFI generation
.PHONY: macos-ffi-amd64 macos-ffi-arm64 macos-ffi-headers ffigen-prep ffigen

macos-ffi-amd64: $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(DARWIN_LIB_AMD64)))
	GOOS=darwin GOARCH=amd64 LIB_NAME=$(DARWIN_LIB_AMD64) $(MAKE) desktop-lib

macos-ffi-arm64: $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(DARWIN_LIB_ARM64)))
	GOOS=darwin GOARCH=arm64 LIB_NAME=$(DARWIN_LIB_ARM64) $(MAKE) desktop-lib

macos-ffi-headers: macos-ffi-arm64
	@echo "macOS FFI headers available under bin/macos-arm64/liblantern.h"

ffigen-prep:
ifeq ($(UNAME_S),Darwin)
	@if [ ! -f "$(MACOS_FFI_HEADER)" ]; then \
		echo "Missing $(MACOS_FFI_HEADER) — generating macOS FFI headers for ffigen..."; \
		$(MAKE) macos-ffi-headers; \
	fi
endif

ffigen: ffigen-prep
	dart run ffigen

pubget:
	flutter pub get

find-duplicate-translations:
	grep -oE 'msgid\s+"[^"]+"' assets/locales/en.po | sort | uniq -d

clean:
	rm -rf $(BUILD_DIR)/*
	rm -rf $(BIN_DIR)/*
	rm -rf $(MACOS_FRAMEWORK_DIR)/*
	rm -rf $(ANDROID_LIB_PATH)
	rm -rf $(IOS_DIR)$(IOS_FRAMEWORK)


#this will used to delete all Lantern data from the user's home directory
PHONY: delete-data
delete-data:
	@echo "Deleting Lantern data..."
	@rm -rf "$(HOME)/Library/Application Support/org.getlantern.lantern"
	@rm -rf "$(HOME)/Library/Logs/Lantern"
	@rm -rf "$(HOME)/.lanternsecrets"
	@rm -rf "/Users/Shared/Lantern/"
	@echo "Lantern data deleted."

.PHONY: protos
# You can install the dart protoc support by running 'dart pub global activate protoc_plugin'
protos:
	@protoc --dart_out=lib/lantern/protos protos/auth.proto
