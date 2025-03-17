.PHONY: gen macos

OUT_DIR := bin

LIB_NAME := liblantern
FFI_DIR := ./lantern-core/ffi

# Build for macOS
macos: export CGO_CFLAGS="-I./dart_api_dl/include"
macos:
	go build -o bin/liblantern.dylib -buildmode=c-shared ./lantern-core/ffi
	mkdir -p build/macos/Build/Products/Debug/Lantern.app/Contents/MacOS
	cp bin/liblantern.dylib build/macos/Build/Products/Debug/Lantern.app/Contents/MacOS

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
gen:
	dart run build_runner build --delete-conflicting-outputs

clean:
	rm -rf $(OUT_DIR)/*