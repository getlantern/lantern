.PHONY: gen macos

BUILD_DIR := bin

APP ?= lantern
CAPITALIZED_APP := Lantern
LANTERN_LIB_NAME := liblantern
LANTERN_CORE := lantern-core
RADIANCE_REPO := github.com/getlantern/radiance
FFI_DIR := $(LANTERN_CORE)/ffi
EXTRA_LDFLAGS ?=
BUILD_TAGS ?=

DARWIN_APP_NAME := $(CAPITALIZED_APP).app
DARWIN_FRAMEWORK_DIR := macos/Frameworks
DARWIN_LIB_NAME := $(DARWIN_FRAMEWORK_DIR)/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_AMD64 := $(BUILD_DIR)/macos-amd64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_ARM64 := $(BUILD_DIR)/macos-arm64/$(LANTERN_LIB_NAME).dylib

LINUX_LIB_NAME := $(BUILD_DIR)/$(LANTERN_LIB_NAME).so
LINUX_LIB_AMD64 := $(BUILD_DIR)/linux-amd64/$(LANTERN_LIB_NAME).so
LINUX_LIB_ARM64 := $(BUILD_DIR)/linux-arm64/$(LANTERN_LIB_NAME).so

WINDOWS_LIB_NAME := $(BUILD_DIR)/$(LANTERN_LIB_NAME).dll
WINDOWS_LIB_AMD64 := $(BUILD_DIR)/windows-amd64/$(LANTERN_LIB_NAME).dll
WINDOWS_LIB_ARM64 := $(BUILD_DIR)/windows-arm64/$(LANTERN_LIB_NAME).dll

ANDROID_LIB_NAME := $(BUILD_DIR)/android/$(LANTERN_LIB_NAME).aar
IOS_FRAMEWORK := $(BUILD_DIR)/ios/$(CAPITALIZED_APP).xcframework

TAGS=with_gvisor

GO_SOURCES := go.mod go.sum $(shell find . -type f -name '*.go')

gen:
	dart run build_runner build --delete-conflicting-outputs

pubget:
	flutter pub get

lantern-lib: export CGO_CFLAGS="-I./dart_api_dl/include"
lantern-lib:
	CGO_ENABLED=1 go build -v -trimpath -buildmode=c-shared -tags="$(BUILD_TAGS)" -ldflags="-w -s $(EXTRA_LDFLAGS)" -o $(LIB_NAME) ./$(FFI_DIR)

# macOS Build
.PHONY: macos-arm64
macos-arm64: $(DARWIN_LIB_ARM64)

$(DARWIN_LIB_ARM64): $(GO_SOURCES)
	GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: macos-amd64
macos-amd64: $(DARWIN_LIB_AMD64)

$(DARWIN_LIB_AMD64): $(GO_SOURCES)
	GOARCH=amd64 LIB_NAME=$@ make lantern-lib

.PHONY: macos
macos: $(DARWIN_LIB_NAME)

$(DARWIN_LIB_NAME): $(GO_SOURCES)
	make macos-arm64 macos-amd64
	mkdir -p $(DARWIN_FRAMEWORK_DIR)
	lipo -create $(DARWIN_LIB_ARM64) $(DARWIN_LIB_AMD64) -output $(DARWIN_LIB_NAME)
	install_name_tool -id "@rpath/${DARWIN_LIB_NAME}" $(DARWIN_LIB_NAME)
	cp $(BUILD_DIR)/macos-amd64/$(LANTERN_LIB_NAME)*.h $(DARWIN_FRAMEWORK_DIR)/

.PHONY: macos-debug
macos-debug: clean macos pubget gen
	@echo "Building Flutter app (debug) for macOS..."
	flutter build macos --debug

.PHONY: macos-release
macos-release: clean macos pubget gen
	@echo "Building Flutter app (release) for macOS..."
	flutter build macos --release

# Linux Build
.PHONY: linux-arm64
linux-arm64: $(LINUX_LIB_ARM64)

$(LINUX_LIB_ARM64): $(GO_SOURCES)
	CC=aarch64-linux-gnu-gcc GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: linux-amd64
linux-amd64: $(LINUX_LIB_AMD64)

$(LINUX_LIB_AMD64): $(GO_SOURCES)
	CC=x86_64-linux-gnu-gcc GOARCH=amd64 LIB_NAME=$@ make lantern-lib

.PHONY: linux
linux: linux-amd64
	cp $(LINUX_LIB_AMD64) $(LINUX_LIB_NAME)

.PHONY: linux-debug
linux-debug:
	@echo "Building Flutter app (debug) for Linux..."
	flutter build linux --debug

.PHONY: linux-release
linux-release: clean linux pubget gen
	@echo "Building Flutter app (release) for Linux..."
	flutter build linux --release

# Windows Build
.PHONY: windows-amd64
windows-amd64: export BUILD_TAGS += walk_use_cgo
windows-amd64: export CGO_LDFLAGS = -static
windows-amd64: $(WINDOWS_LIB_AMD64)

$(WINDOWS_LIB_AMD64): $(GO_SOURCES)
	GOOS=windows GOARCH=amd64 LIB_NAME=$@ make lantern-lib

.PHONY: windows-arm64
windows-arm64: export BUILD_TAGS += walk_use_cgo
windows-arm64: export CGO_LDFLAGS = -static
windows-arm64: $(WINDOWS_LIB_ARM64)

$(WINDOWS_LIB_ARM64): $(GO_SOURCES)
	GOOS=windows GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: windows
windows: windows-amd64

$(WINDOWS_LIB_NAME): $(GO_SOURCES)
	GOARCH=amd64 LIB_NAME=$@ make lantern-lib

# Android Build
.PHONY: install-android-deps
install-android-deps:
	@echo "Installing Android dependencies..."

	go install golang.org/x/mobile/cmd/gomobile@latest
	gomobile init

.PHONY: android
android: $(ANDROID_LIB_NAME)

$(ANDROID_LIB_NAME): $(GO_SOURCES)
	make install-android-deps
	@echo "Building Android library..."
	mkdir -p $(BUILD_DIR)/android
	GOOS=android gomobile bind -v -androidapi=21 -tags=$(TAGS) -trimpath -target=android -o $@ $(RADIANCE_REPO)
	@echo "Built Android library: $@"

# iOS Build
.PHONY: ios
ios: $(IOS_FRAMEWORK)

$(IOS_FRAMEWORK): $(GO_SOURCES)
	@echo "Building iOS Framework..."
	mkdir -p $(BUILD_DIR)/ios
	GOOS=ios gomobile bind -v -tags=$(TAGS),with_low_memory -trimpath -target=ios -ldflags="-w -s" -o $@ $(RADIANCE_REPO)
	@echo "Built iOS Framework: $@"

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


find-duplicate-translations:
	grep -oE 'msgid\s+"[^"]+"' assets/locales/en.po | sort | uniq -d

clean:
	flutter clean
	rm -rf $(BUILD_DIR)/*
	rm -rf $(DARWIN_FRAMEWORK_DIR)/*