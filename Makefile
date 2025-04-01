.PHONY: gen macos ffi

OUT_DIR := bin

LIB_NAME := liblantern
LIB_FOLDER := android/app/libs
ANDROID_LIB_PATH := android/app/libs/$(LIB_NAME).aar
ANDROID_LIB := $(LIB_NAME).aar
TAGS=with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc
FFI_DIR := ./lantern-core/ffi
RADIANCE_REPO := github.com/getlantern/radiance


# Missing and Guards

check-gomobile:
	@if ! command -v gomobile &> /dev/null; then \
		echo "gomobile not found. Installing..."; \
		go install golang.org/x/mobile/cmd/gomobile@latest; \
		gomobile init; \
	else \
		echo "gomobile is already installed."; \
	fi


require-gomobile:
	@if [[ -z "$(SENTRY)" ]]; then echo 'Missing "sentry-cli" command. See sentry.io for installation instructions.'; exit 1; fi


##### Build Libraries #####

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

build-android:check-gomobile
	@echo "Building Android libraries"
	rm -rf $(OUT_DIR)/$(ANDROID_LIB)
	rm -rf $(ANDROID_LIB_PATH)
	mkdir -p $(LIB_FOLDER)
	gomobile bind -v \
		-target=android \
		-androidapi=23 \
		-javapkg=lantern.io \
		-tags=$(TAGS) -trimpath \
		-o=$(OUT_DIR)/$(ANDROID_LIB) \
		-ldflags="-checklinkname=0" \
		 $(RADIANCE_REPO) github.com/sagernet/sing-box/experimental/libbox ./lantern-core/mobile
	cp $(OUT_DIR)/$(ANDROID_LIB) $(ANDROID_LIB_PATH)
	@echo "Android libraries built successfully"


### End Build Libraries ###


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
ffi:
	dart run ffigen


find-duplicate-translations:
	grep -oE 'msgid\s+"[^"]+"' assets/locales/en.po | sort | uniq -d

clean:
	rm -rf $(OUT_DIR)/*