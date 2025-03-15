.PHONY: gen macos

OUT_DIR := bin

APP ?= lantern
CAPITALIZED_APP := Lantern
LANTERN_LIB_NAME := liblantern
LANTERN_CORE := lantern-core
FFI_DIR := $(LANTERN_CORE)/ffi
EXTRA_LDFLAGS ?=
TAGS ?=

DARWIN_APP_NAME ?= $(CAPITALIZED_APP).app
DARWIN_FRAMEWORK_DIR ?= macos/Frameworks
DARWIN_LIB_NAME ?= $(LANTERN_LIB_NAME).dylib
DARWIN_LIB_AMD64 ?= $(OUT_DIR)/$(LANTERN_LIB_NAME)_amd64.dylib
DARWIN_LIB_ARM64 ?= $(OUT_DIR)/$(LANTERN_LIB_NAME)_arm64.dylib

LINUX_LIB_NAME ?= $(OUT_DIR)/$(LANTERN_LIB_NAME).so
LINUX_LIB_AMD64 ?= $(OUT_DIR)/amd64/$(LANTERN_LIB_NAME).so
LINUX_LIB_ARM64 ?= $(OUT_DIR)/arm64/$(LANTERN_LIB_NAME).so

gen:
	dart run build_runner build

lantern-lib:
	CGO_ENABLED=1 go build -trimpath -buildmode=c-shared -ldflags="-w -s $(EXTRA_LDFLAGS)" -o $(LIB_NAME) ./$(FFI_DIR)

# Build for macOS
macos-arm64: $(DARWIN_LIB_ARM64)
$(DARWIN_LIB_ARM64): export CGO_CFLAGS="-I./dart_api_dl/include"
$(DARWIN_LIB_ARM64): export LIB_NAME = $(DARWIN_LIB_ARM64)
$(DARWIN_LIB_ARM64): export GOOS = darwin
$(DARWIN_LIB_ARM64): export GOARCH = arm64
$(DARWIN_LIB_ARM64): lantern-lib

macos-amd64: $(DARWIN_LIB_AMD64)
$(DARWIN_LIB_AMD64): export CGO_CFLAGS="-I./dart_api_dl/include"
$(DARWIN_LIB_AMD64): export LIB_NAME = $(DARWIN_LIB_AMD64)
$(DARWIN_LIB_AMD64): export GOOS = darwin
$(DARWIN_LIB_AMD64): export GOARCH = amd64
$(DARWIN_LIB_AMD64): lantern-lib

.PHONY: macos
macos: macos-arm64
	make macos-amd64
	echo "Nuking $(DARWIN_FRAMEWORK_DIR)"
	rm -Rf $(DARWIN_FRAMEWORK_DIR)/*
	mkdir -p $(DARWIN_FRAMEWORK_DIR)
	lipo -create $(DARWIN_LIB_ARM64) $(DARWIN_LIB_AMD64) \
		-output "${DARWIN_FRAMEWORK_DIR}/${DARWIN_LIB_NAME}"
	install_name_tool -id "@rpath/${DARWIN_LIB_NAME}" "${DARWIN_FRAMEWORK_DIR}/${DARWIN_LIB_NAME}"
	cp $(OUT_DIR)/$(DESKTOP_LIB_NAME)*.h $(DARWIN_FRAMEWORK_DIR)/


# Build for Linux
linux-arm64: $(LINUX_LIB_ARM64)
$(LINUX_LIB_ARM64): export LIB_NAME = $(LINUX_LIB_ARM64)
$(LINUX_LIB_ARM64): export GOOS = linux
$(LINUX_LIB_ARM64): export GOARCH = arm64
$(LINUX_LIB_ARM64): export EXTRA_LDFLAGS += -linkmode external
$(LINUX_LIB_ARM64): lantern-lib


linux-amd64: $(LINUX_LIB_AMD64)
$(LINUX_LIB_AMD64): export LIB_NAME = $(LINUX_LIB_AMD64)
$(LINUX_LIB_AMD64): export GOOS = linux
$(LINUX_LIB_AMD64): export GOARCH = amd64
$(LINUX_LIB_AMD64): export EXTRA_LDFLAGS += -linkmode external
$(LINUX_LIB_AMD64): lantern-lib

.PHONY: linux
linux: linux-arm64
	cp $(LINUX_LIB_ARM64) $(LINUX_LIB_NAME)

# Build for iOS
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

#Routes generation
routes:
	dart run build_runner build --delete-conflicting-outputs

clean:
	rm -rf $(OUT_DIR)/*