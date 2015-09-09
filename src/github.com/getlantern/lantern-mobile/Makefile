APK_FILE := ./app/build/outputs/apk/lantern-debug.apk
LANTERN_DIR := ../../../../
LANTERN_MOBILE_DIR := src/github.com/getlantern/lantern-mobile

define pkg_variables
	$(eval PACKAGE := $(shell aapt dump badging $(APK_FILE)|awk -F" " '/package/ {print $$2}'|awk -F"'" '/name=/ {print $$2}'))
	$(eval MAIN_ACTIVITY := $(shell aapt dump badging $(APK_FILE)|awk -F" " '/launchable-activity/ {print $$2}'|awk -F"'" '/name=/ {print $$2}' | grep MainActivity))
endef

.PHONY: all

all: build-debug install run watch

compile-debug:
	./gradlew \
		lantern:compileDebugSources \
		lantern:compileDebugAndroidTestSources

build-debug:
	./gradlew assembleDebug

build-tun2socks:
	ndk-build
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

watch:
	adb logcat | grep `adb shell ps | grep org.getlantern.lantern | cut -c10-15`

clean:
	./gradlew clean
