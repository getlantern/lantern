.PHONY: gen macos ffi

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
EXTRA_LDFLAGS ?=
BUILD_TAGS ?=

DARWIN_APP_NAME := $(CAPITALIZED_APP).app
DARWIN_FRAMEWORK_DIR := macos/Frameworks
DARWIN_LIB := $(LANTERN_LIB_NAME).dylib
DARWIN_LIB_AMD64 := $(BIN_DIR)/macos-amd64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_ARM64 := $(BIN_DIR)/macos-arm64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_BUILD := $(BIN_DIR)/macos/$(DARWIN_LIB)
DARWIN_DEBUG_BUILD := $(BUILD_DIR)/macos/Build/Products/Debug/$(DARWIN_APP_NAME)
DARWIN_RELEASE_BUILD := $(BUILD_DIR)/macos/Build/Products/Release/$(DARWIN_APP_NAME)
MACOS_ENTITLEMENTS := macos/Runner/Release.entitlements
MACOS_INSTALLER := $(INSTALLER_NAME)$(if $(BUILD_TYPE),-$(BUILD_TYPE)).dmg

LINUX_LIB := $(LANTERN_LIB_NAME).so
LINUX_LIB_AMD64 := $(BIN_DIR)/linux-amd64/$(LANTERN_LIB_NAME).so
LINUX_LIB_ARM64 := $(BIN_DIR)/linux-arm64/$(LANTERN_LIB_NAME).so
LINUX_LIB_BUILD := $(BIN_DIR)/linux/$(LINUX_LIB)
LINUX_INSTALLER_DEB := $(INSTALLER_NAME)$(if $(BUILD_TYPE),-$(BUILD_TYPE)).deb
LINUX_INSTALLER_RPM := $(INSTALLER_NAME)$(if $(BUILD_TYPE),-$(BUILD_TYPE)).rpm

ifeq ($(OS),Windows_NT)
	PATH_SEP := \\
else
	PATH_SEP := /
endif

define join_path
$(subst /,$(PATH_SEP),$1)
endef

WINDOWS_LIB := $(LANTERN_LIB_NAME).dll
WINDOWS_LIB_AMD64 := $(call join_path,$(BIN_DIR)/windows-amd64/$(WINDOWS_LIB))
WINDOWS_LIB_ARM64 := $(call join_path,$(BIN_DIR)/windows-arm64/$(WINDOWS_LIB))
WINDOWS_LIB_BUILD := $(call join_path,$(BIN_DIR)/windows/$(WINDOWS_LIB))
WINDOWS_RELEASE_DIR := $(call join_path,$(BUILD_DIR)/windows/x64/runner/Release)

ANDROID_LIB := $(LANTERN_LIB_NAME).aar
ANDROID_LIBS_DIR := android/app/libs
ANDROID_LIB_BUILD := $(BIN_DIR)/android/$(ANDROID_LIB)
ANDROID_LIB_PATH := android/app/libs/$(LANTERN_LIB_NAME).aar
ANDROID_DEBUG_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-debug.apk
ANDROID_APK_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/flutter-apk/app-release.apk
ANDROID_AAB_RELEASE_BUILD := $(BUILD_DIR)/app/outputs/bundle/release/app-release.aab
ANDROID_TARGET_PLATFORMS := android-arm,android-arm64,android-x64
ANDROID_RELEASE_APK := $(INSTALLER_NAME)$(if $(BUILD_TYPE),-$(BUILD_TYPE)).apk
ANDROID_RELEASE_AAB := $(INSTALLER_NAME)$(if $(BUILD_TYPE),-$(BUILD_TYPE)).aab

IOS_FRAMEWORK := Liblantern.xcframework
IOS_FRAMEWORK_DIR := ios/Frameworks
IOS_FRAMEWORK_BUILD := $(BIN_DIR)/ios/$(IOS_FRAMEWORK)
IOS_DEBUG_BUILD := $(BUILD_DIR)/ios/iphoneos/Runner.app

TAGS=with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc

GO_SOURCES := go.mod go.sum $(shell find . -type f -name '*.go')
GOMOBILE_VERSION ?= latest
GOMOBILE_REPOS = \
	$(RADIANCE_REPO) \
	github.com/sagernet/sing-box/experimental/libbox \
	github.com/getlantern/sing-box-extensions/ruleset \
	./lantern-core/mobile

SIGN_ID="Developer ID Application: Brave New Software Project, Inc (ACZRKC3LQ9)"

define osxcodesign
	codesign --deep --options runtime --strict --timestamp --force --entitlements $(MACOS_ENTITLEMENTS) -s $(SIGN_ID) -v $(1)
endef

get-command = $(shell which="$$(which $(1) 2> /dev/null)" && if [[ ! -z "$$which" ]]; then printf %q "$$which"; fi)
APPDMG    := $(call get-command,appdmg)

## APP_VERSION is the version defined in pubspec.yaml
APP_VERSION := $(shell grep '^version:' pubspec.yaml | sed 's/version: //;s/ //g')

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
  NORMALIZED_CURDIR := $(shell echo $(CURDIR) | sed 's|\\|/|g')
  SETENV = set CGO_ENABLED=1&& set CGO_CFLAGS=-I$(NORMALIZED_CURDIR)/dart_api_dl/include&&
else
  SETENV = CGO_ENABLED=1 CGO_CFLAGS=-I$(CURDIR)/dart_api_dl/include
endif

.PHONY: desktop-lib
desktop-lib:
	$(SETENV) go build -v -trimpath -buildmode=c-shared \
		-tags="$(TAGS)" \
		-ldflags="-w -s $(EXTRA_LDFLAGS)" \
		-o $(LIB_NAME) ./$(FFI_DIR)

# macOS Build
.PHONY: install-macos-deps

install-macos-deps:
	npm install -g appdmg
	brew tap joshdk/tap
	brew install joshdk/tap/retry
	brew install imagemagick || true
	dart pub global activate flutter_distributor

.PHONY: macos-arm64
macos-arm64: $(DARWIN_LIB_ARM64)

$(DARWIN_LIB_ARM64): $(GO_SOURCES)
	GOARCH=arm64 LIB_NAME=$@ make desktop-lib

.PHONY: macos-amd64
macos-amd64: $(DARWIN_LIB_AMD64)

$(DARWIN_LIB_AMD64): $(GO_SOURCES)
	GOARCH=amd64 LIB_NAME=$@ make desktop-lib

.PHONY: macos
macos: $(DARWIN_LIB_BUILD)

$(DARWIN_LIB_BUILD): $(GO_SOURCES)
	$(MAKE) macos-arm64 macos-amd64
	rm -rf $@ && mkdir -p $(dir $@)
	lipo -create $(DARWIN_LIB_ARM64) $(DARWIN_LIB_AMD64) -output $@
	install_name_tool -id "@rpath/${DARWIN_LIB}" $@
	mkdir -p $(DARWIN_FRAMEWORK_DIR) && cp $@ $(DARWIN_FRAMEWORK_DIR)
	cp $(BIN_DIR)/macos-amd64/$(LANTERN_LIB_NAME)*.h $(DARWIN_FRAMEWORK_DIR)/
	@echo "Built macOS library: $(DARWIN_FRAMEWORK_DIR)/$(DARWIN_LIB)"

.PHONY: macos-debug
macos-debug: $(DARWIN_DEBUG_BUILD)

$(DARWIN_DEBUG_BUILD): $(DARWIN_LIB_BUILD)
	@echo "Building Flutter app (debug) for macOS..."
	flutter build macos --debug

$(DARWIN_RELEASE_BUILD):
	@echo "Building Flutter app (release) for macOS..."
	flutter build macos --release

build-macos-release: $(DARWIN_RELEASE_BUILD)

.PHONY: notarize-darwin
notarize-darwin: require-ac-username require-ac-password
	@echo "Notarizing distribution package..."
	xcrun notarytool submit $(MACOS_INSTALLER) \
		--apple-id $$AC_USERNAME \
		--team-id "ACZRKC3LQ9" \
		--password $$AC_PASSWORD \
		--wait

	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(MACOS_INSTALLER)
	@echo "Notarization complete"

sign-app:
	$(call osxcodesign,$(DARWIN_RELEASE_BUILD))

package-macos: require-appdmg
	appdmg appdmg.json $(MACOS_INSTALLER)

.PHONY: macos-release
macos-release: clean macos pubget gen build-macos-release sign-app package-macos notarize-darwin

# Linux Build
.PHONY: install-linux-deps

install-linux-deps:
	dart pub global activate flutter_distributor

.PHONY: linux-arm64
linux-arm64: $(LINUX_LIB_ARM64)

$(LINUX_LIB_ARM64): $(GO_SOURCES)
	CC=aarch64-linux-gnu-gcc GOARCH=arm64 LIB_NAME=$@ make desktop-lib

.PHONY: linux-amd64
linux-amd64: $(LINUX_LIB_AMD64)

$(LINUX_LIB_AMD64): $(GO_SOURCES)
	CC=x86_64-linux-gnu-gcc GOARCH=amd64 LIB_NAME=$@ make desktop-lib

.PHONY: linux
linux: linux-amd64
	mkdir -p $(BIN_DIR)/linux
	cp $(LINUX_LIB_AMD64) $(LINUX_LIB_BUILD)

.PHONY: linux-debug
linux-debug:
	@echo "Building Flutter app (debug) for Linux..."
	flutter build linux --debug

.PHONY: linux-release
linux-release: clean linux pubget gen
	@echo "Building Flutter app (release) for Linux..."
	flutter build linux --release
	cp $(LINUX_LIB_BUILD) build/linux/x64/release/bundle
	flutter_distributor package --platform linux --targets "deb,rpm" --skip-clean
	mv $(DIST_OUT)/$(APP_VERSION)/lantern-$(APP_VERSION)-linux.rpm $(LINUX_INSTALLER_RPM)
	mv $(DIST_OUT)/$(APP_VERSION)/lantern-$(APP_VERSION)-linux.deb $(LINUX_INSTALLER_DEB)

# Windows Build
.PHONY: install-windows-deps
install-windows-deps:
	dart pub global activate flutter_distributor

windows: windows-amd64

windows-amd64: WINDOWS_GOOS := windows
windows-amd64: WINDOWS_GOARCH := amd64
windows-amd64:
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_AMD64)

windows-arm64: WINDOWS_GOOS := windows
windows-arm64: WINDOWS_GOARCH := arm64
windows-arm64:
	$(MAKE) desktop-lib GOOS=$(WINDOWS_GOOS) GOARCH=$(WINDOWS_GOARCH) LIB_NAME=$(WINDOWS_LIB_ARM64)

.PHONY: windows-debug
windows-debug: windows
	@echo "Building Flutter app (debug) for Windows..."
	flutter build windows --debug

.PHONY: windows-release
windows-release: clean windows pubget gen
	flutter_distributor package --flutter-build-args=verbose --platform windows --targets "exe"

# Android Build
.PHONY: install-android-deps
install-android-deps:
	@echo "Installing Android dependencies..."

	go install -v golang.org/x/mobile/cmd/gomobile@$(GOMOBILE_VERSION)
	go install -v golang.org/x/mobile/cmd/gobind@$(GOMOBILE_VERSION)
	gomobile init

.PHONY: android
android: check-gomobile $(ANDROID_LIB_BUILD)

$(ANDROID_LIB_BUILD): $(GO_SOURCES)
	$(MAKE) build-android

build-android: check-gomobile
	@echo "Building Android libraries..."
	rm -rf $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)
	mkdir -p $(dir $(ANDROID_LIB_BUILD)) $(ANDROID_LIBS_DIR)

	GOOS=android gomobile bind -v \
		-androidapi=23 \
		-javapkg=lantern.io \
		-tags=$(TAGS) -trimpath \
		-o=$(ANDROID_LIB_BUILD) \
		-ldflags="-checklinkname=0" \
		$(GOMOBILE_REPOS)

	cp $(ANDROID_LIB_BUILD) $(ANDROID_LIBS_DIR)
	@echo "Built Android library: $(ANDROID_LIBS_DIR)/$(ANDROID_LIB)"

.PHONY: android-debug
android-debug: $(ANDROID_DEBUG_BUILD)

$(ANDROID_DEBUG_BUILD): $(ANDROID_LIB_BUILD)
	flutter build apk --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --debug

.PHONY: android-apk-release
android-apk-release:
	flutter build apk --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --release
	cp $(ANDROID_APK_RELEASE_BUILD) $(ANDROID_RELEASE_APK)

.PHONY: android-aab-release
android-aab-release:
	flutter build appbundle --target-platform $(ANDROID_TARGET_PLATFORMS) --verbose --release
	cp $(ANDROID_AAB_RELEASE_BUILD) $(ANDROID_RELEASE_AAB)

.PHONY: android-release
android-release: clean android pubget gen android-apk-release

# iOS Build
.PHONY: install-ios-deps

install-ios-deps:
	npm install -g appdmg
	dart pub global activate flutter_distributor

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
		-tags=$(TAGS),with_low_memory,netgo -trimpath \
		-target=ios \
		-o $(IOS_FRAMEWORK_BUILD) \
		-ldflags="-w -s -checklinkname=0" \
		$(RADIANCE_REPO) github.com/sagernet/sing-box/experimental/libbox github.com/getlantern/sing-box-extensions/ruleset  ./lantern-core/mobile
	@echo "Built iOS Framework: $(IOS_FRAMEWORK_BUILD)"
	mv $(IOS_FRAMEWORK_BUILD) $(IOS_FRAMEWORK_DIR)

.PHONY: swift-format
swift-format:
	swift-format format --in-place --recursive ios/Runner macos/Runner

ios-release: clean pubget
	flutter build ipa --flavor prod --release --export-options-plist ./ExportOptions.plist
	@IPA_PATH=$(shell pwd)/build/ios/ipa; \
	echo "iOS IPA generated under: $$IPA_PATH"; \
	open "$$IPA_PATH"

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

#FFI generation
ffigen:
	dart run ffigen

pubget:
	flutter pub get


find-duplicate-translations:
	grep -oE 'msgid\s+"[^"]+"' assets/locales/en.po | sort | uniq -d

clean:
	rm -rf $(BUILD_DIR)/*
	rm -rf $(BIN_DIR)/*
	rm -rf $(DARWIN_FRAMEWORK_DIR)/*
	rm -rf $(ANDROID_LIB_PATH)