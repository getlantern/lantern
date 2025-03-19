.PHONY: gen macos

OUT_DIR := bin

APP ?= lantern
CAPITALIZED_APP := Lantern
LANTERN_LIB_NAME := liblantern
LANTERN_CORE := lantern-core
FFI_DIR := $(LANTERN_CORE)/ffi
EXTRA_LDFLAGS ?=
BUILD_TAGS ?=

DARWIN_APP_NAME ?= $(CAPITALIZED_APP).app
DARWIN_FRAMEWORK_DIR ?= macos/Frameworks
DARWIN_LIB_NAME ?= $(DARWIN_FRAMEWORK_DIR)/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_AMD64 ?= $(OUT_DIR)/macos-amd64/$(LANTERN_LIB_NAME).dylib
DARWIN_LIB_ARM64 ?= $(OUT_DIR)/macos-arm64/$(LANTERN_LIB_NAME).dylib

LINUX_LIB_NAME ?= $(OUT_DIR)/$(LANTERN_LIB_NAME).so
LINUX_LIB_AMD64 ?= $(OUT_DIR)/linux-amd64/$(LANTERN_LIB_NAME).so
LINUX_LIB_ARM64 ?= $(OUT_DIR)/linux-arm64/$(LANTERN_LIB_NAME).so

WINDOWS_LIB_NAME := $(OUT_DIR)/$(LANTERN_LIB_NAME).dll
WINDOWS_LIB_AMD64 := $(OUT_DIR)/windows-amd64/$(LANTERN_LIB_NAME).dll
WINDOWS_LIB_ARM64 := $(OUT_DIR)/windows-arm64/$(LANTERN_LIB_NAME).dll

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

$(DARWIN_LIB_ARM64):
	GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: macos-amd64
macos-amd64: $(DARWIN_LIB_AMD64)

$(DARWIN_LIB_AMD64):
	GOARCH=amd64 LIB_NAME=$@ make lantern-lib

.PHONY: macos
macos: $(DARWIN_LIB_NAME)

$(DARWIN_LIB_NAME):
	make macos-arm64 macos-amd64
	lipo -create $(DARWIN_LIB_ARM64) $(DARWIN_LIB_AMD64) -output $(DARWIN_LIB_NAME)
	install_name_tool -id "@rpath/${DARWIN_LIB_NAME}" $(DARWIN_LIB_NAME)
	cp $(OUT_DIR)/macos-amd64/$(LANTERN_LIB_NAME)*.h $(DARWIN_FRAMEWORK_DIR)/

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

$(LINUX_LIB_ARM64):
	CC=aarch64-linux-gnu-gcc GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: linux-amd64
linux-amd64: $(LINUX_LIB_AMD64)

$(LINUX_LIB_AMD64):
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

$(WINDOWS_LIB_AMD64):
	GOOS=windows GOARCH=amd64 LIB_NAME=$@ make lantern-lib

.PHONY: windows-arm64
windows-arm64: export BUILD_TAGS += walk_use_cgo
windows-arm64: export CGO_LDFLAGS = -static
windows-arm64: $(WINDOWS_LIB_ARM64)

$(WINDOWS_LIB_ARM64):
	GOOS=windows GOARCH=arm64 LIB_NAME=$@ make lantern-lib

.PHONY: windows
windows: windows-amd64

$(WINDOWS_LIB_NAME):
	GOARCH=amd64 LIB_NAME=$@ make lantern-lib

# iOS Build
build-ios-device:
	GOOS=ios GOARCH=arm64 SDK=iphoneos LIB_NAME=$(LIB_NAME) $(PWD)/build-ios.sh

build-ios-simulator-arm64:
	GOOS=ios GOARCH=arm64 SDK=iphonesimulator LIB_NAME=$(LIB_NAME) $(PWD)/build-ios.sh

build-ios-simulator-amd64:
	GOOS=ios GOARCH=amd64 SDK=iphonesimulator LIB_NAME=$(LIB_NAME) $(PWD)/build-ios.sh

build-ios: build-ios-device build-ios-simulator-arm64 build-ios-simulator-amd64
	lipo -create bin/iphonesimulator/$(LIB_NAME)_amd64.a \
		bin/iphonesimulator/$(LIB_NAME)_arm64.a \
		-output bin/iphonesimulator/$(LIB_NAME).a
	mv bin/iphoneos/liblantern_arm64.a bin/iphoneos/liblantern.a
	mv bin/iphoneos/liblantern_arm64.h bin/iphoneos/liblantern.h

build-framework: build-ios
	rm -rf ios/$(LIB_NAME).xcframework
	xcodebuild -create-xcframework -output ios/$(LIB_NAME).xcframework -library bin/iphoneos/$(LIB_NAME).a \
	-headers bin/iphoneos/$(LIB_NAME).h -library bin/iphonesimulator/$(LIB_NAME).a \
	-headers bin/iphonesimulator/$(LIB_NAME)_arm64.h
	cp ios/Liblantern.podspec ios/liblantern.xcframework

ios:
	GOOS=ios CGO_ENABLED=1 go build -trimpath -buildmode=c-archive -o $(OUT_DIR)/$(LIB_NAME)_$(GOARCH)_$(SDK).a

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
	rm -rf $(OUT_DIR)/*
	rm -rf $(DARWIN_FRAMEWORK_DIR)/*