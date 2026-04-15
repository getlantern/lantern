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
## APP_VERSION is the version defined in pubspec.yaml
ifeq ($(OS),Windows_NT)
APP_VERSION := $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command "$$v=(Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$$').Matches[0].Groups[1].Value.Trim(); Write-Output $$v")
APP_VERSION_PUBSPEC := $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command "$$v=(Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$$').Matches[0].Groups[1].Value.Trim(); Write-Output ($$v.Split('+')[0])")
else
APP_VERSION := $(shell grep '^version:' pubspec.yaml | sed 's/version: //;s/ //g')
APP_VERSION_PUBSPEC := $(shell grep '^version:' pubspec.yaml | sed 's/version: //;s/+.*//;s/ //g')
endif
EXTRA_LDFLAGS ?= -X '$(RADIANCE_REPO)/common.Version=$(APP_VERSION_PUBSPEC)'

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
LINUX_SERVICE_NAME := lanternd
LINUX_SERVICE_SRC  := $(RADIANCE_REPO)/cmd/lanternd
LINUX_SERVICE_BUILD_AMD64 := $(BIN_DIR)/linux-amd64/$(LINUX_SERVICE_NAME)
LINUX_SERVICE_BUILD_ARM64 := $(BIN_DIR)/linux-arm64/$(LINUX_SERVICE_NAME)
LINUX_SERVICE_BUILD_TARGET := $(BIN_DIR)/linux-$(LINUX_TARGET_ARCH)/$(LINUX_SERVICE_NAME)
LINUX_BUNDLE_DIR_X64 := build/linux/x64/release/bundle
LINUX_BUNDLE_DIR_ARM64 := build/linux/arm64/release/bundle
LINUX_CC_AMD64 ?= x86_64-linux-gnu-gcc
LINUX_CC_ARM64 ?= aarch64-linux-gnu-gcc
LINUX_PKG_ROOT := linux/packaging
LINUX_SERVICE_DST := $(LINUX_PKG_ROOT)/usr/sbin
LINUX_PKG_SYSTEMD_DIR := $(LINUX_PKG_ROOT)/usr/lib/systemd/system
LINUX_SYSTEMD_UNIT_SRC := $(shell go list -m -f '{{.Dir}}' $(RADIANCE_REPO))/cmd/lanternd/lanternd.service
LINUX_SYSTEMD_UNIT_DST := $(LINUX_PKG_SYSTEMD_DIR)/lanternd.service

ifeq ($(OS),Windows_NT)
  PS := powershell -NoProfile -ExecutionPolicy Bypass -Command
  MKDIR_P = $(PS) "New-Item -ItemType Directory -Force -Path '$(1)' | Out-Null"
  COPY_FILE = $(PS) "Copy-Item -Force -LiteralPath '$(1)' -Destination '$(2)'"
  RM_RF = $(PS) "Remove-Item -Recurse -Force -LiteralPath '$(1)'"
else
  MKDIR_P = mkdir -p -- '$(1)'
  COPY_FILE = cp -f -- '$(1)' '$(2)'
  RM_RF = rm -rf -- '$(1)'
endif

WINDOWS_SERVICE_NAME := lanternsvc.exe
WINDOWS_SERVICE_SRC  := ./$(LANTERN_CORE)/cmd/lanternsvc
WINDOWS_SERVICE_BUILD_AMD64 := $(BIN_DIR)/windows-amd64/$(WINDOWS_SERVICE_NAME)
WINDOWS_SERVICE_BUILD_ARM64 := $(BIN_DIR)/windows-arm64/$(WINDOWS_SERVICE_NAME)
WINDOWS_SERVICE_BUILD := $(WINDOWS_SERVICE_BUILD_AMD64)
WINDOWS_SERVICE_CGO_ENABLED ?= 0

WINDOWS_LIB          := $(LANTERN_LIB_NAME).dll
WINDOWS_LIB_AMD64    := $(BIN_DIR)/windows-amd64/$(WINDOWS_LIB)
WINDOWS_LIB_ARM64    := $(BIN_DIR)/windows-arm64/$(WINDOWS_LIB)
WINDOWS_LIB_BUILD    := $(BIN_DIR)/windows/$(WINDOWS_LIB)
WINDOWS_DEBUG_DIR    := $(BUILD_DIR)/windows/x64/runner/Debug
WINDOWS_RELEASE_DIR  := $(BUILD_DIR)/windows/x64/runner/Release
WINDOWS_SERVICE_BUILD_ARM64_RELEASE := $(WINDOWS_RELEASE_DIR)/arm64/$(WINDOWS_SERVICE_NAME)
WINTUN_VERSION ?= 0.14.1
WINTUN_BASE_URL := https://wwW.wintun.net
WINTUN_BUILDS_URL  := $(WINTUN_BASE_URL)/builds
WINTUN_OUT_DIR_AMD64 := windows/third_party/wintun/bin/amd64
WINTUN_OUT_DIR_ARM64 := windows/third_party/wintun/bin/arm64
WINTUN_DLL_AMD64     := $(WINTUN_OUT_DIR_AMD64)/wintun.dll
WINTUN_DLL_ARM64     := $(WINTUN_OUT_DIR_ARM64)/wintun.dll
WINTUN_DLL           := $(WINTUN_DLL_AMD64)
WINTUN_DLL_RELEASE := $(WINDOWS_RELEASE_DIR)/wintun.dll
WINTUN_DLL_RELEASE_ARM64 := $(WINDOWS_RELEASE_DIR)/arm64/wintun.dll
WINTUN_DLL_DEBUG   := $(WINDOWS_DEBUG_DIR)/wintun.dll


ANDROID_LIB := $(LANTERN_LIB_NAME).aar
ANDROID_LIBS_DIR := android/app/libs
ANDROID_LIB_BUILD := $(BIN_DIR)/android/$(ANDROID_LIB)
ANDROID_LIB_PATH := android/app/libs/$(LANTERN_LIB_NAME).aar
ANDROID_DEBUG_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-debug.apk
ANDROID_APK_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
ANDROID_TARGET_PLATFORMS := android-arm,android-arm64
ANDROID_RELEASE_APK := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).apk
ANDROID_RELEASE_AAB := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).aab
ANDROID_MAPPING_SRC := build/app/outputs/mapping/release/mapping.txt
ANDROID_SYMBOLS_SRC := build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip
ANDROID_NDK_VERSION          ?= 28.2.13676358
ANDROID_CMAKE_VERSION        ?= 3.22.1
ANDROID_BUILD_TOOLS_VERSION  ?= 35.0.0
ANDROID_PLATFORM             ?= android-35
ANDROID_SDK_ROOT             := $(or $(ANDROID_SDK_ROOT),$(ANDROID_HOME))
SDKMANAGER                   := $(ANDROID_SDK_ROOT)/cmdline-tools/latest/bin/sdkmanager
ANDROID_PAGE_SIZE ?= 16384
# Android 15+ Play requirement: arm64 native libs must be linked for 16 KB page-size compatibility.
ANDROID_GOMOBILE_LDFLAGS ?= -checklinkname=0 -extldflags=-Wl,-z,max-page-size=$(ANDROID_PAGE_SIZE),-z,common-page-size=$(ANDROID_PAGE_SIZE)

IOS_INSTALLER := $(INSTALLER_NAME)$(if $(filter-out production,$(BUILD_TYPE)),-$(BUILD_TYPE)).ipa
IOS_DIR := ios/
IOS_FRAMEWORK := Liblantern.xcframework
IOS_FRAMEWORK_DIR := ios/Frameworks
IOS_FRAMEWORK_BUILD := $(BIN_DIR)/ios/$(IOS_FRAMEWORK)
IOS_DEBUG_BUILD := $(BUILD_DIR)/ios/iphoneos/Runner.app

TAGS=with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_conntrack,with_dhcp,with_acme,with_tailscale

WINDOWS_CGO_LDFLAGS=-static-libgcc -static-libstdc++ -static -lwinpthread

ifeq ($(OS),Windows_NT)
GO_VERSION ?= $(shell powershell -NoProfile -ExecutionPolicy Bypass -Command "$$line=(Select-String -Path 'go.mod' -Pattern '^go\s+(.+)$$').Matches[0].Groups[1].Value.Trim(); Write-Output ('go'+$$line)")
GO_SOURCES := go.mod go.sum
UNAME_S := Windows
else
GO_VERSION ?= $(shell grep '^go ' go.mod | awk '{print "go" $$2}')
GO_SOURCES := go.mod go.sum $(shell find . -type f -name '*.go')
UNAME_S := $(shell uname -s)
endif
GOMOBILECACHE ?= $(HOME)/.cache/gomobile
GOMOBILE_ANDROID_TARGET ?= android/arm,android/arm64
GOMOBILE_VERSION ?= latest
GOMOBILE_REPOS = \
	github.com/sagernet/sing-box/experimental/libbox \
	./lantern-core/mobile \
	./lantern-core/utils

SIGN_ID="Developer ID Application: Brave New Software Project, Inc (ACZRKC3LQ9)"

define osxcodesign
	codesign --deep --options runtime --strict --timestamp --force --entitlements $(1) -s $(SIGN_ID) -v $(2)
endef

get-command = $(shell which="$$(which $(1) 2> /dev/null)" && if [[ ! -z "$$which" ]]; then printf %q "$$which"; fi)
APPDMG    := $(call get-command,appdmg)

DART_DEFINES := --dart-define=BUILD_TYPE=$(BUILD_TYPE) $(if $(VERSION),--dart-define=VERSION=$(VERSION),)

INSTALLER_RESOURCES := installer-resources

# Missing and Guards
guard-%:
	 @ if [ -z '${${*}}' ]; then echo 'Environment  $* variable not set' && exit 1; fi

check-gomobile:
	@command -v gomobile >/dev/null || (echo "gomobile not found. Run 'make install-android-deps'" && exit 1)

require-gomobile:
	@if [[ -z "$(SENTRY)" ]]; then echo 'Missing "sentry-cli" command. See sentry.io for installation instructions.'; exit 1; fi

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
desktop-lib:
	$(SETENV) go build -v -trimpath -buildmode=c-shared \
		-tags="$(TAGS)" \
		-ldflags="-w -s $(EXTRA_LDFLAGS)" \
		-o $(LIB_NAME) ./$(FFI_DIR)
	@echo "Built desktop library: $(LIB_NAME)"

# macOS build tools need to be installed when generating release builds,
# but are not necessarily required for debug builds
.PHONY: install-macos-deps

install-macos-deps: install-gomobile
	npm install -g appdmg
	brew tap joshdk/tap
	brew install joshdk/tap/retry
	brew install imagemagick || true

.PHONY: macos
macos: $(MACOS_FRAMEWORK_BUILD)

$(MACOS_FRAMEWORK_BUILD): $(GO_SOURCES)
	@echo "Building macOS Framework.."
	rm -rf $(MACOS_FRAMEWORK_BUILD) && mkdir -p $(MACOS_FRAMEWORK_DIR)
	GOTOOLCHAIN=$(GO_VERSION) GOOS=darwin gomobile bind -v \
		-tags=$(TAGS),netgo  -trimpath \
		-target=macos \
		-o $(MACOS_FRAMEWORK_BUILD) \
		-ldflags="-w -s -checklinkname=0 $(EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS)
	@echo "Built macOS Framework: $(MACOS_FRAMEWORK_BUILD)"
	rm -rf $(MACOS_FRAMEWORK_DIR)/$(MACOS_FRAMEWORK)
	mv $(MACOS_FRAMEWORK_BUILD) $(MACOS_FRAMEWORK_DIR)


.PHONY: macos-framework
macos-framework: $(MACOS_FRAMEWORK_BUILD)

.PHONY: macos-debug
macos-debug: $(DARWIN_DEBUG_BUILD)

$(DARWIN_DEBUG_BUILD): $(DARWIN_LIB_BUILD)
	@echo "Building Flutter app (debug) for macOS..."
	flutter build macos --debug

.PHONY: macos-unit-tests
macos-unit-tests: $(MACOS_FRAMEWORK_BUILD)
	@echo "Preparing macOS test project (building native assets)..."
	flutter build macos --debug
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

$(DARWIN_RELEASE_BUILD):
	@echo "Building Flutter app (release) for macOS..."
	rm -vf $(MACOS_INSTALLER)
	flutter build macos --release $(DART_DEFINES)

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
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(MACOS_INSTALLER)
	@echo "Notarization complete"


.PHONY: notarize-log
notarize-log:
	xcrun notarytool log 3036c6b2-8f99-44d7-8c3e-6c9c007b2524 \
		--apple-id $$AC_USERNAME \
		--team-id "ACZRKC3LQ9" \
		--password $$AC_PASSWORD
	    --output-format json > notary_log.json
sign-app:
	$(call osxcodesign, $(PACKET_ENTITLEMENTS), $(SYSTEM_EXTENSION_DIR)/Contents/Frameworks/Liblantern.framework)
	$(call osxcodesign, $(PACKET_ENTITLEMENTS), $(SYSTEM_EXTENSION_DIR)/Contents/MacOS/org.getlantern.lantern.PacketTunnel)
	$(call osxcodesign, $(PACKET_ENTITLEMENTS), $(SYSTEM_EXTENSION_DIR))
	$(call osxcodesign, $(MACOS_ENTITLEMENTS), $(DARWIN_RELEASE_BUILD))

package-macos: require-appdmg
	appdmg appdmg.json $(MACOS_INSTALLER)

.PHONY: macos-release
macos-release: clean macos pubget gen build-macos-release sign-app package-macos notarize-darwin

# Linux Build
.PHONY: install-linux-deps

install-linux-deps:
	@command -v nfpm >/dev/null 2>&1 || \
		{ echo "Installing nfpm..."; go install github.com/goreleaser/nfpm/v2/cmd/nfpm@v2.45.0; }

.PHONY: linux-arm64
linux-arm64: $(LINUX_LIB_ARM64)

$(LINUX_LIB_ARM64): $(GO_SOURCES)
	CC=$(LINUX_CC_ARM64) GOOS=linux GOARCH=arm64 LIB_NAME=$@ $(MAKE) desktop-lib

.PHONY: linux-amd64
linux-amd64: $(LINUX_LIB_AMD64)

$(LINUX_LIB_AMD64): $(GO_SOURCES)
	CC=$(LINUX_CC_AMD64) GOOS=linux GOARCH=amd64 LIB_NAME=$@ $(MAKE) desktop-lib

.PHONY: linux
linux: linux-$(LINUX_TARGET_ARCH)
	mkdir -p $(BIN_DIR)/linux
	cp $(BIN_DIR)/linux-$(LINUX_TARGET_ARCH)/$(LINUX_LIB) $(LINUX_LIB_BUILD)

.PHONY: linux-service-amd64 linux-service-arm64 linux-service stage-linux-service

linux-service-amd64: $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(LINUX_SERVICE_BUILD_AMD64)))
	GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
	  go build -v -trimpath -tags "$(TAGS)" \
	  -ldflags "-w -s $(EXTRA_LDFLAGS)" \
	  -o $(LINUX_SERVICE_BUILD_AMD64) $(LINUX_SERVICE_SRC)
	@echo "Built Linux service: $(LINUX_SERVICE_BUILD_AMD64)"

linux-service-arm64: $(GO_SOURCES)
	$(call MKDIR_P,$(dir $(LINUX_SERVICE_BUILD_ARM64)))
	GOOS=linux GOARCH=arm64 CGO_ENABLED=1 \
	  go build -v -trimpath -tags "$(TAGS)" \
	  -ldflags "-w -s $(EXTRA_LDFLAGS)" \
	  -o $(LINUX_SERVICE_BUILD_ARM64) $(LINUX_SERVICE_SRC)
	@echo "Built Linux service: $(LINUX_SERVICE_BUILD_ARM64)"

linux-service: linux-service-$(LINUX_TARGET_ARCH)

stage-linux-service: linux-service
	@echo "Staging systemd unit + service binary $(LINUX_PKG_ROOT)..."
	$(call MKDIR_P,$(LINUX_SERVICE_DST))
	$(call COPY_FILE,$(LINUX_SERVICE_BUILD_TARGET),$(LINUX_SERVICE_DST)/$(LINUX_SERVICE_NAME))
	$(call MKDIR_P,$(LINUX_PKG_SYSTEMD_DIR))
	$(call COPY_FILE,$(LINUX_SYSTEMD_UNIT_SRC),$(LINUX_SYSTEMD_UNIT_DST))

.PHONY: linux-debug
linux-debug:
	@echo "Building Flutter app (debug) for Linux..."
	flutter build linux --debug

.PHONY: linux-release linux-release-ci
linux-release: clean linux-release-ci

linux-release-ci: linux pubget gen
	@echo "Building Flutter app (release) for Linux..."
	flutter build linux --release $(DART_DEFINES)
	$(MAKE) stage-linux-service

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
	patchelf --set-rpath '$$ORIGIN/lib' "$$BUNDLE_DIR/lantern" || true; \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" SYSTEMD_UNIT_SRC=$(LINUX_SYSTEMD_UNIT_DST) \
	LANTERND_SRC=$(LINUX_SERVICE_DST)/$(LINUX_SERVICE_NAME) LANTERND_DST=/usr/sbin/$(LINUX_SERVICE_NAME) \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p deb -t $(LINUX_INSTALLER_DEB); \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" SYSTEMD_UNIT_SRC=$(LINUX_SYSTEMD_UNIT_DST) \
	LANTERND_SRC=$(LINUX_SERVICE_DST)/$(LINUX_SERVICE_NAME) LANTERND_DST=/usr/sbin/$(LINUX_SERVICE_NAME) \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p rpm -t $(LINUX_INSTALLER_RPM); \
	VERSION=$(APP_VERSION) GOARCH=$(LINUX_TARGET_ARCH) LINUX_BUNDLE_SRC="$$BUNDLE_DIR/" SYSTEMD_UNIT_SRC=$(LINUX_SYSTEMD_UNIT_DST) \
	LANTERND_SRC=$(LINUX_SERVICE_DST)/$(LINUX_SERVICE_NAME) LANTERND_DST=/usr/bin/$(LINUX_SERVICE_NAME) \
		nfpm package -f $(LINUX_PKG_ROOT)/nfpm.yaml -p archlinux -t $(LINUX_INSTALLER_ARCH)

.PHONY: verify-linux-package
verify-linux-package:
	./scripts/ci/verify_linux_package.sh $(LINUX_INSTALLER_DEB)

# Windows Build
.PHONY: build-lanternsvc-windows build-lanternsvc-windows-arm64 \
        windows-service-build windows-service-build-amd64 windows-service-build-arm64 \
        copy-lanternsvc-release copy-lanternsvc-release-arm64 copy-lanternsvc-debug \
        wintun wintun-amd64 wintun-arm64 clean-wintun \
        copy-wintun-release copy-wintun-release-arm64 copy-wintun-debug

.PHONY: install-windows-deps
install-windows-deps:
	dart pub global activate fastforge

windows: windows-amd64
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_BUILD)))
	$(call COPY_FILE,$(WINDOWS_LIB_AMD64),$(WINDOWS_LIB_BUILD))

windows-amd64: WINDOWS_GOOS := windows
windows-amd64: WINDOWS_GOARCH := amd64
windows-amd64:
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_AMD64)))
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_AMD64) CGO_LDFLAGS="$(WINDOWS_CGO_LDFLAGS)"
windows-arm64: WINDOWS_GOOS := windows
windows-arm64: WINDOWS_GOARCH := arm64
windows-arm64:
	$(call MKDIR_P,$(dir $(WINDOWS_LIB_ARM64)))
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_ARM64) CGO_LDFLAGS="$(WINDOWS_CGO_LDFLAGS)"

.PHONY: build-lanternsvc-windows
build-lanternsvc-windows: $(WINDOWS_SERVICE_BUILD_AMD64)

.PHONY: build-lanternsvc-windows-arm64
build-lanternsvc-windows-arm64: $(WINDOWS_SERVICE_BUILD_ARM64)

windows-service-build: windows-service-build-amd64

windows-service-build-amd64: $(WINDOWS_SERVICE_BUILD_AMD64)

windows-service-build-arm64: $(WINDOWS_SERVICE_BUILD_ARM64)

$(WINDOWS_SERVICE_BUILD_AMD64):
	$(call MKDIR_P,$(dir $(WINDOWS_SERVICE_BUILD_AMD64)))
	GOOS=windows GOARCH=amd64 CGO_ENABLED=$(WINDOWS_SERVICE_CGO_ENABLED) go build -v -trimpath -tags "$(TAGS)" \
		-ldflags "$(EXTRA_LDFLAGS)" \
		-o $(WINDOWS_SERVICE_BUILD_AMD64) $(WINDOWS_SERVICE_SRC)
	@echo "Built Windows service (amd64): $(WINDOWS_SERVICE_BUILD_AMD64)"

$(WINDOWS_SERVICE_BUILD_ARM64):
	$(call MKDIR_P,$(dir $(WINDOWS_SERVICE_BUILD_ARM64)))
	GOOS=windows GOARCH=arm64 CGO_ENABLED=$(WINDOWS_SERVICE_CGO_ENABLED) go build -v -trimpath -tags "$(TAGS)" \
		-ldflags "$(EXTRA_LDFLAGS)" \
		-o $(WINDOWS_SERVICE_BUILD_ARM64) $(WINDOWS_SERVICE_SRC)
	@echo "Built Windows service (arm64): $(WINDOWS_SERVICE_BUILD_ARM64)"

copy-lanternsvc-release: $(WINDOWS_SERVICE_BUILD_AMD64)
	$(call MKDIR_P,$(WINDOWS_RELEASE_DIR))
	$(call COPY_FILE,$(WINDOWS_SERVICE_BUILD_AMD64),$(WINDOWS_RELEASE_DIR)/$(WINDOWS_SERVICE_NAME))

copy-lanternsvc-release-arm64: $(WINDOWS_SERVICE_BUILD_ARM64)
	$(call MKDIR_P,$(dir $(WINDOWS_SERVICE_BUILD_ARM64_RELEASE)))
	$(call COPY_FILE,$(WINDOWS_SERVICE_BUILD_ARM64),$(WINDOWS_SERVICE_BUILD_ARM64_RELEASE))

copy-lanternsvc-debug: $(WINDOWS_SERVICE_BUILD_AMD64)
	$(call MKDIR_P,$(WINDOWS_DEBUG_DIR))
	$(call COPY_FILE,$(WINDOWS_SERVICE_BUILD_AMD64),$(WINDOWS_DEBUG_DIR)/$(WINDOWS_SERVICE_NAME))

wintun: wintun-amd64

wintun-amd64: $(WINTUN_DLL_AMD64)

wintun-arm64: $(WINTUN_DLL_ARM64)

clean-wintun:
	@$(call RM_RF,$(WINTUN_OUT_DIR_AMD64))
	@$(call RM_RF,$(WINTUN_OUT_DIR_ARM64))

$(WINTUN_DLL_AMD64):
	$(call MKDIR_P,$(WINTUN_OUT_DIR_AMD64))
	@ver='$(WINTUN_VERSION)'; \
	  zip='$(WINTUN_OUT_DIR_AMD64)/wintun-'$$ver'.zip'; \
	  url='$(WINTUN_BUILDS_URL)/wintun-'$$ver'.zip'; \
	  echo "Using Wintun $$ver"; \
	  curl -fsSL -o "$$zip" "$$url"; \
	  $(call MKDIR_P,$(WINTUN_OUT_DIR_AMD64)/_unz); \
	  tar -xf "$$zip" -C "$(WINTUN_OUT_DIR_AMD64)/_unz" "wintun/bin/amd64/wintun.dll" \
	    || powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '$$zip' -DestinationPath '$(WINTUN_OUT_DIR_AMD64)/_unz'";
	$(call COPY_FILE,$(WINTUN_OUT_DIR_AMD64)/_unz/wintun/bin/amd64/wintun.dll,$(WINTUN_DLL_AMD64))
	$(call RM_RF,$(WINTUN_OUT_DIR_AMD64)/_unz)
	@echo "Installed: $(WINTUN_DLL_AMD64)";

$(WINTUN_DLL_ARM64):
	$(call MKDIR_P,$(WINTUN_OUT_DIR_ARM64))
	@ver='$(WINTUN_VERSION)'; \
	  zip='$(WINTUN_OUT_DIR_ARM64)/wintun-'$$ver'.zip'; \
	  url='$(WINTUN_BUILDS_URL)/wintun-'$$ver'.zip'; \
	  echo "Using Wintun $$ver"; \
	  curl -fsSL -o "$$zip" "$$url"; \
	  $(call MKDIR_P,$(WINTUN_OUT_DIR_ARM64)/_unz); \
	  tar -xf "$$zip" -C "$(WINTUN_OUT_DIR_ARM64)/_unz" "wintun/bin/arm64/wintun.dll" \
	    || powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '$$zip' -DestinationPath '$(WINTUN_OUT_DIR_ARM64)/_unz'";
	$(call COPY_FILE,$(WINTUN_OUT_DIR_ARM64)/_unz/wintun/bin/arm64/wintun.dll,$(WINTUN_DLL_ARM64))
	$(call RM_RF,$(WINTUN_OUT_DIR_ARM64)/_unz)
	@echo "Installed: $(WINTUN_DLL_ARM64)";

.PHONY: copy-wintun-release copy-wintun-debug
copy-wintun-release: $(WINTUN_DLL_AMD64)
	$(call MKDIR_P,$(WINDOWS_RELEASE_DIR))
	$(call COPY_FILE,$(WINTUN_DLL_AMD64),$(WINTUN_DLL_RELEASE))

copy-wintun-release-arm64: $(WINTUN_DLL_ARM64)
	$(call MKDIR_P,$(dir $(WINTUN_DLL_RELEASE_ARM64)))
	$(call COPY_FILE,$(WINTUN_DLL_ARM64),$(WINTUN_DLL_RELEASE_ARM64))

copy-wintun-debug: $(WINTUN_DLL_AMD64)
	$(call MKDIR_P,$(WINDOWS_DEBUG_DIR))
	$(call COPY_FILE,$(WINTUN_DLL_AMD64),$(WINTUN_DLL_DEBUG))

.PHONY: prepare-windows-release
prepare-windows-release: build-lanternsvc-windows build-lanternsvc-windows-arm64 wintun-amd64 wintun-arm64
	$(MAKE) copy-lanternsvc-release
	$(MAKE) copy-lanternsvc-release-arm64
	$(MAKE) copy-wintun-release
	$(MAKE) copy-wintun-release-arm64

.PHONY: windows-debug
windows-debug: windows
	@echo "Building Flutter app (debug) for Windows..."
	flutter build windows --debug

.PHONY: build-windows-release
build-windows-release:
	@echo "Building Flutter app (release) for Windows..."
	flutter build windows --release --verbose

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

.PHONY: install-android-deps
install-android-deps: install-gomobile

.PHONY: android
android: check-android-sdk check-gomobile $(ANDROID_LIB_BUILD)

$(ANDROID_LIB_BUILD): $(GO_SOURCES)
	$(MAKE) build-android

build-android: check-android-sdk check-gomobile
	@echo "Building Android libraries..."
	rm -rf $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)
	mkdir -p $(dir $(ANDROID_LIB_BUILD)) $(ANDROID_LIBS_DIR)

	GOMOBILECACHE="$(GOMOBILECACHE)" \
	GOTOOLCHAIN=$(GO_VERSION) GOOS=android gomobile bind -v \
		-androidapi=23 \
		-target="$(GOMOBILE_ANDROID_TARGET)" \
		-javapkg=lantern.io \
		-tags=$(TAGS) -trimpath \
		-o=$(ANDROID_LIB_BUILD) \
		-ldflags="$(ANDROID_GOMOBILE_LDFLAGS) $(EXTRA_LDFLAGS)" \
		$(GOMOBILE_REPOS)

	cp $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)
	@echo "Built Android library: $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)"

.PHONY: android-debug
android-debug: $(ANDROID_DEBUG_BUILD)

$(ANDROID_DEBUG_BUILD): $(ANDROID_LIB_BUILD)
	flutter build apk --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --debug

.PHONY: android-apk-release
android-apk-release:
	flutter build apk --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --release $(DART_DEFINES)
	cp $(ANDROID_APK_RELEASE_BUILD) $(ANDROID_RELEASE_APK)

.PHONY: android-aab-release
android-aab-release:
	flutter build appbundle --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --release $(DART_DEFINES)
	cp $(ANDROID_AAB_RELEASE_BUILD) $(ANDROID_RELEASE_AAB)
	# Copy Play console artifacts
	@if [ -f "$(ANDROID_MAPPING_SRC)" ]; then \
	  cp "$(ANDROID_MAPPING_SRC)" mapping.txt; \
	fi

	@if [ -f "$(ANDROID_SYMBOLS_SRC)" ]; then \
	  cp "$(ANDROID_SYMBOLS_SRC)" debug-symbols.zip; \
	elif [ -d "build/app/intermediates/merged_native_libs/release/out/lib" ]; then \
	  (cd build/app/intermediates/merged_native_libs/release/out && zip -r ../../../../../../debug-symbols.zip lib >/dev/null); \
	fi


.PHONY: android-release
android-release: clean android pubget gen android-apk-release

.PHONY: android-release-ci
android-release-ci: android pubget gen android-apk-release android-aab-release

# iOS Build
.PHONY: install-ios-deps

install-ios-deps: install-gomobile
	npm install -g appdmg

.PHONY: ios
ios: $(IOS_FRAMEWORK_BUILD)

.PHONY: ios
ios: check-gomobile $(IOS_FRAMEWORK_BUILD)

$(IOS_FRAMEWORK_BUILD): $(GO_SOURCES)
	$(MAKE) build-ios

build-ios:
	@echo "Building iOS Framework.."
	rm -rf $(IOS_FRAMEWORK_BUILD)
	rm -rf $(IOS_FRAMEWORK_DIR) && mkdir -p $(IOS_FRAMEWORK_DIR)
	GOOS=ios gomobile bind -v \
		-tags=$(TAGS),with_low_memory, -trimpath \
		-target=ios \
		-o $(IOS_FRAMEWORK_BUILD) \
		-ldflags="-w -s -checklinkname=0 $(EXTRA_LDFLAGS)" \
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

ios-release: clean pubget ios
	flutter build ipa --release --export-options-plist ./ExportOptions.plist $(DART_DEFINES)
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
