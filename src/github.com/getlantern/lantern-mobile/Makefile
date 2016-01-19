S3CMD := $(shell which s3cmd 2> /dev/null)
S3_BUCKET ?= lantern-android

BUILD_DIR := ./app/build/outputs/apk
LANTERN_DEBUG_APK := lantern-debug.apk
APK_FILE := ./app/build/outputs/apk/lantern-debug.apk
LANTERN_DIR := ../../../../
LANTERN_MOBILE_DIR := src/github.com/getlantern/lantern-mobile

define pkg_variables
$(eval PACKAGE := $(shell aapt dump badging $(APK_FILE)|awk -F" " '/package/ {print $$2}'|awk -F"'" '/name=/ {print $$2}'))
$(eval MAIN_ACTIVITY := $(shell aapt dump badging $(APK_FILE)|awk -F" " '/launchable-activity/ {print $$2}'|awk -F"'" '/name=/ {print $$2}' | grep MainActivity))
endef

.PHONY: all

all: build-debug install run logcat

compile-debug:
	./gradlew \
		lantern:compileDebugSources \
		lantern:compileDebugAndroidTestSources

build-debug:
	./gradlew assembleDebug

build-tun2socks:
	ndk-build
	mkdir -p app/libs/armeabi-v7a
	cp libs/armeabi-v7a/libtun2socks.so app/libs/armeabi-v7a/

build-lantern:
	cd $(LANTERN_DIR); make android-lib

$(APK_FILE): build-debug

install: $(APK_FILE)
	adb install -r $(APK_FILE)

uninstall:
	$(call pkg_variables)
	adb uninstall $(PACKAGE)

run:
	$(call pkg_variables)
	echo $(PACKAGE)
	echo $(MAIN_ACTIVITY)
	adb shell am start -n $(PACKAGE)/$(MAIN_ACTIVITY)

require-version:
	@if [[ -z "$$VERSION" ]]; then echo "VERSION environment value is required."; exit 1; fi

require-s3cmd:
	@if [[ -z "$(S3CMD)" ]]; then echo 'Missing "s3cmd" command. Use "brew install s3cmd" or see https://github.com/s3tools/s3cmd/blob/master/INSTALL'; exit 1; fi

release-beta: require-version require-s3cmd
	@BASE_NAME="lantern-android-beta" && \
		rm -f $$BASE_NAME* && \
		cp $(BUILD_DIR)/$(LANTERN_DEBUG_APK) $$BASE_NAME.apk && \
		for NAME in $$(ls -1 $$BASE_NAME*.*); do \
			shasum $$NAME | cut -d " " -f 1 > $$NAME.sha1 && \
			echo "Uploading SHA-1 `cat $$NAME.sha1`" && \
			$(S3CMD) put -P $$NAME.sha1 s3://$(S3_BUCKET) && \
			echo "Uploading $$NAME to S3" && \
			$(S3CMD) put -P $$NAME s3://$(S3_BUCKET) && \
			SUFFIX=$$(echo "$$NAME" | sed s/$$BASE_NAME//g) && \
			VERSIONED=lantern-installer-$$VERSION$$SUFFIX && \
			echo "Copying $$VERSIONED" && \
			$(S3CMD) cp s3://$(S3_BUCKET)/$$NAME s3://$(S3_BUCKET)/$$VERSIONED && \
			$(S3CMD) setacl s3://$(S3_BUCKET)/$$VERSIONED --acl-public; \
		done

logcat:
	adb logcat | grep `adb shell ps | grep org.getlantern.lantern | cut -c10-15`

clean:
	./gradlew clean
