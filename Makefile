SHELL := /bin/bash

OSX_MIN_VERSION := 10.9

SOURCES := $(shell find src -name '*[^_test].go')

get-command = $(shell which="$$(which $(1) 2> /dev/null)" && if [[ ! -z "$$which" ]]; then printf %q "$$which"; fi)

DOCKER 		:= $(call get-command,docker)
GO 		:= $(call get-command,go)
NODE 		:= $(call get-command,node)
NPM 		:= $(call get-command,npm)
GULP 		:= $(call get-command,gulp)
S3CMD 		:= $(call get-command,s3cmd)
WGET 		:= $(call get-command,wget)
RUBY 		:= $(call get-command,ruby)

APPDMG 		:= $(call get-command,appdmg)
SVGEXPORT 	:= $(call get-command,svgexport)

DOCKERMACHINE 	:= $(call get-command,docker-machine)
BOOT2DOCKER 	:= $(call get-command,boot2docker)

GIT_REVISION_SHORTCODE := $(shell git rev-parse --short HEAD)
GIT_REVISION := $(shell git describe --abbrev=0 --tags --exact-match 2> /dev/null || git rev-parse --short HEAD)
GIT_REVISION_DATE := $(shell git show -s --format=%ci $(GIT_REVISION_SHORTCODE))

REVISION_DATE := $(shell date -u -j -f "%F %T %z" "$(GIT_REVISION_DATE)" +"%Y%m%d.%H%M%S" 2>/dev/null || date -u -d "$(GIT_REVISION_DATE)" +"%Y%m%d.%H%M%S")
BUILD_DATE := $(shell date -u +%Y%m%d.%H%M%S)

LOGGLY_TOKEN := 2b68163b-89b6-4196-b878-c1aca4bbdf84

LDFLAGS_NOSTRIP := -X github.com/getlantern/flashlight.Version=$(GIT_REVISION) -X github.com/getlantern/flashlight.RevisionDate=$(REVISION_DATE) -X github.com/getlantern/flashlight.BuildDate=$(BUILD_DATE) -X github.com/getlantern/flashlight/logging.logglyToken=$(LOGGLY_TOKEN) -X github.com/getlantern/flashlight/logging.logglyTag=$(LOGGLY_TAG)
LDFLAGS := $(LDFLAGS_NOSTRIP) -s
LANTERN_DESCRIPTION := Censorship circumvention tool
LANTERN_EXTENDED_DESCRIPTION := Lantern allows you to access sites blocked by internet censorship.\nWhen you run it, Lantern reroutes traffic to selected domains through servers located where such domains are uncensored.

PACKAGE_VENDOR := Brave New Software Project, Inc
PACKAGE_MAINTAINER := Lantern Team <team@getlantern.org>
PACKAGE_URL := https://www.getlantern.org
PACKAGED_YAML := .packaged-lantern.yaml
MANOTO_YAML := .packaged-lantern-manoto.yaml

RESOURCES_DOT_GO := ./src/github.com/getlantern/flashlight/ui/resources.go

ifdef SECRETS_DIR
BNS_CERT := $(SECRETS_DIR)/bns.pfx
DOCKER_VOLS = "-v $$PWD:/lantern $(SECRETS_VOL) -v $$SECRETS_DIR:/secrets"
else
BNS_CERT := "../secrets/bns.pfx"
DOCKER_VOLS = "-v $$PWD:/lantern $(SECRETS_VOL)"
endif

LANTERN_BINARIES_PATH ?= ../lantern-binaries

GH_USER ?= getlantern

GH_RELEASE_REPOSITORY ?= lantern

S3_BUCKET ?= lantern

DOCKER_IMAGE_TAG := lantern-builder

S3_BUCKET ?= lantern
ANDROID_S3_BUCKET ?= lantern-android
ANDROID_BUILD_DIR := src/github.com/getlantern/lantern-mobile/app/build/outputs/apk
LANTERN_DEBUG_APK := lantern-debug.apk

ANDROID_LIB_PKG := github.com/getlantern/lantern
ANDROID_LIB := liblantern.aar

ANDROID_SDK_DIR := MobileSDK
ANDROID_SDK_LIBS := $(ANDROID_SDK_DIR)/sdk/libs/
ANDROID_SDK_ANDROID_LIB := $(ANDROID_SDK_LIBS)/$(ANDROID_LIB)
ANDROID_SDK := $(ANDROID_SDK_DIR)/sdk/build/outputs/aar/sdk-debug.aar

PUBSUB_JAVA_DIR := pubsub-java
PUBSUB_JAVA := $(PUBSUB_JAVA_DIR)/build/libs/pubsub-java-fat.jar

PUBSUB_DIR := PubSub
PUBSUB_LIBS := $(PUBSUB_DIR)/sdk/libs
PUBSUB_PUBSUB_JAVA_LIB := $(PUBSUB_LIBS)/pubsub-java-fat.jar
PUBSUB := $(PUBSUB_DIR)/sdk/build/outputs/aar/sdk-debug.aar

ANDROID_TESTBED_DIR := LanternMobileTestbed
ANDROID_TESTBED_LIBS := $(ANDROID_TESTBED_DIR)/app/libs/
ANDROID_TESTBED_ANDROID_LIB := $(ANDROID_TESTBED_LIBS)/$(ANDROID_LIB)
ANDROID_TESTBED_ANDROID_SDK := $(ANDROID_TESTBED_LIBS)/android-sdk-debug.aar
ANDROID_TESTBED_PUBSUB := $(ANDROID_TESTBED_LIBS)/pubsub-sdk-debug.aar
ANDROID_TESTBED := $(ANDROID_TESTBED_DIR)/app/build/outputs/apk/app-debug.apk

LANTERN_MOBILE_DIR := src/github.com/getlantern/lantern-mobile
LANTERN_MOBILE_LIBS := $(LANTERN_MOBILE_DIR)/app/libs
TUN2SOCKS := $(LANTERN_MOBILE_DIR)/libs/armeabi-v7a/libtun2socks.so
LANTERN_MOBILE_ARM_LIBS := $(LANTERN_MOBILE_LIBS)/armeabi-v7a
LANTERN_MOBILE_TUN2SOCKS := $(LANTERN_MOBILE_ARM_LIBS)/libtun2socks.so
LANTERN_MOBILE_ANDROID_LIB := $(LANTERN_MOBILE_LIBS)/$(ANDROID_LIB)
LANTERN_MOBILE_ANDROID_SDK := $(LANTERN_MOBILE_LIBS)/android-sdk-debug.aar
LANTERN_MOBILE_PUBSUB  := $(LANTERN_MOBILE_LIBS)/pubsub-sdk-debug.aar
LANTERN_MOBILE_ANDROID_DEBUG := $(LANTERN_MOBILE_DIR)/app/build/outputs/apk/lantern-debug.apk
LANTERN_MOBILE_ANDROID_RELEASE := $(LANTERN_MOBILE_DIR)/app/build/outputs/apk/app-release.apk

LANTERN_YAML := lantern.yaml
LANTERN_YAML_PATH := installer-resources/lantern.yaml

BUILD_TAGS ?=

.PHONY: packages clean tun2socks android-lib android-sdk android-testbed android-debug android-release android-install docker-run

define require-node
	if [[ -z "$(NODE)" ]]; then echo 'Missing "node" command.'; exit 1; fi
endef

define require-gulp
	$(call require-node) && if [[ -z "$(GULP)" ]]; then echo 'Missing "gulp" command. Try "npm install -g gulp-cli"'; exit 1; fi
endef

define require-npm
	$(call require-node) && if [[ -z "$(NPM)" ]]; then echo 'Missing "npm" command.'; exit 1; fi
endef

define build-tags
	BUILD_TAGS="$(BUILD_TAGS)" && \
	EXTRA_LDFLAGS="" && \
	if [[ ! -z "$$VERSION" ]]; then \
		EXTRA_LDFLAGS="-X github.com/getlantern/flashlight.compileTimePackageVersion=$$VERSION"; \
	else \
		echo "** VERSION was not set, using default version. This is OK while in development."; \
	fi && \
	if [[ ! -z "$$HEADLESS" ]]; then \
		BUILD_TAGS="$$BUILD_TAGS headless"; \
	fi && \
	BUILD_TAGS=$$(echo $$BUILD_TAGS | xargs) && echo "Build tags: $$BUILD_TAGS" && \
	EXTRA_LDFLAGS=$$(echo $$EXTRA_LDFLAGS | xargs) && echo "Extra ldflags: $$EXTRA_LDFLAGS"
endef

define fpm-debian-build =
	echo "Running fpm-debian-build" && \
 	PKG_ARCH=$1 && \
	WORKDIR=$$(mktemp -dt "$$(basename $$0).XXXXXXXXXX") && \
	INSTALLER_RESOURCES=./installer-resources/linux && \
	\
	mkdir -p $$WORKDIR/usr/bin && \
	mkdir -p $$WORKDIR/usr/lib/lantern && \
	mkdir -p $$WORKDIR/usr/share/applications && \
	mkdir -p $$WORKDIR/usr/share/icons/hicolor/128x128/apps && \
	mkdir -p $$WORKDIR/usr/share/doc/lantern && \
	chmod -R 755 $$WORKDIR && \
	\
	cp $$INSTALLER_RESOURCES/deb-copyright $$WORKDIR/usr/share/doc/lantern/copyright && \
	cp $$INSTALLER_RESOURCES/lantern.desktop $$WORKDIR/usr/share/applications && \
	cp $$INSTALLER_RESOURCES/icon128x128on.png $$WORKDIR/usr/share/icons/hicolor/128x128/apps/lantern.png && \
	\
	cp lantern_linux_$$PKG_ARCH $$WORKDIR/usr/lib/lantern/lantern-binary && \
	cp $$INSTALLER_RESOURCES/lantern.sh $$WORKDIR/usr/lib/lantern && \
	\
	chmod -x $$WORKDIR/usr/lib/lantern/lantern-binary && \
	chmod +x $$WORKDIR/usr/lib/lantern/lantern.sh && \
	\
	ln -s /usr/lib/lantern/lantern.sh $$WORKDIR/usr/bin/lantern && \
	rm -f $$WORKDIR/usr/lib/lantern/$(PACKAGED_YAML) && \
	rm -f $$WORKDIR/usr/lib/lantern/$(LANTERN_YAML) && \
	cp installer-resources/$(PACKAGED_YAML) $$WORKDIR/usr/lib/lantern/$(PACKAGED_YAML) && \
	cp $(LANTERN_YAML_PATH) $$WORKDIR/usr/lib/lantern/$(LANTERN_YAML) && \
	\
	cat $$WORKDIR/usr/lib/lantern/lantern-binary | bzip2 > update_linux_$$PKG_ARCH.bz2 && \
	fpm -a $$PKG_ARCH -s dir -t deb -n lantern -v $$VERSION -m "$(PACKAGE_MAINTAINER)" --description "$(LANTERN_DESCRIPTION)\n$(LANTERN_EXTENDED_DESCRIPTION)" --category net --license "Apache-2.0" --vendor "$(PACKAGE_VENDOR)" --url $(PACKAGE_URL) --deb-compression xz -f -C $$WORKDIR usr && \
	\
	cp installer-resources/$(MANOTO_YAML) $$WORKDIR/usr/lib/lantern/$(PACKAGED_YAML) && \
	fpm -a $$PKG_ARCH -s dir -t deb -n lantern-manoto -v $$VERSION -m "$(PACKAGE_MAINTAINER)" --description "$(LANTERN_DESCRIPTION)\n$(LANTERN_EXTENDED_DESCRIPTION)" --category net --license "Apache-2.0" --vendor "$(PACKAGE_VENDOR)" --url $(PACKAGE_URL) --deb-compression xz -f -C $$WORKDIR usr;
endef

define docker-up
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		if [[ -z "$(DOCKERMACHINE)" ]]; then \
		  if [[ -z "$(BOOT2DOCKER)" ]]; then \
  			echo 'Missing "docker-machine" command' && exit 1; \
			fi && \
			echo "Falling back to using $(BOOT2DOCKER), recommend upgrading to latest docker toolbox from https://www.docker.com/docker-toolbox" && \
			if [[ "$$($(BOOT2DOCKER) status)" != "running" ]]; then \
				$(BOOT2DOCKER) up; \
			fi && \
			if [[ -z "$$DOCKER_HOST" ]]; then \
				$$($(BOOT2DOCKER) shellinit 2>/dev/null); \
			fi \
		else \
		  echo "Using $(DOCKERMACHINE)" && \
			if [[ "$$($(DOCKERMACHINE) status default)" != "Running" ]]; then \
				$(DOCKERMACHINE) start default; \
			fi && \
			$$($(DOCKERMACHINE) env default 2>/dev/null | head -4 | tr -d '"'); \
		fi \
	fi
endef

# This implicit rule allows prefix any existing target with "docker-" to make it
# run in docker.
docker-%: system-checks
	@$(call docker-up) && \
	DOCKER_CONTEXT=.$(DOCKER_IMAGE_TAG)-context && \
	mkdir -p $$DOCKER_CONTEXT && \
	cp Dockerfile $$DOCKER_CONTEXT && \
	docker build -t $(DOCKER_IMAGE_TAG) $$DOCKER_CONTEXT && \
	docker run -e CMD -e VERSION -e HEADLESS -e BNS_CERT_PASS `echo $(DOCKER_VOLS) | xargs` -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && make $*';

all: binaries
android-dist: genconfig android

$(RESOURCES_DOT_GO):
	@$(call require-npm) && \
	$(call require-gulp) && \
	source setenv.bash && \
	LANTERN_UI="lantern-ui" && \
	APP="$$LANTERN_UI/app" && \
	DIST="$$LANTERN_UI/dist" && \
	echo 'var LANTERN_BUILD_REVISION = "$(GIT_REVISION_SHORTCODE)";' > $$APP/js/revision.js && \
	git update-index --assume-unchanged $$APP/js/revision.js && \
	DEST="$@" && \
	cd $$LANTERN_UI && \
	$(NPM) install && \
	rm -Rf dist && \
	$(GULP) build && \
	cd - && \
	rm -f bin/tarfs && \
	go build -o bin/tarfs github.com/getlantern/tarfs/tarfs && \
	echo "// +build !stub" > $$DEST && \
	echo " " >> $$DEST && \
	bin/tarfs -pkg ui $$DIST >> $$DEST

# Generates a syso file that embeds an icon for the Windows executable
generate-windows-icon:
	@source setenv.bash && \
	rm -f bin/rsrc && \
	go install github.com/akavel/rsrc && \
  rsrc -ico installer-resources/windows/lantern.ico -o src/github.com/getlantern/flashlight/lantern_windows_386.syso

assets: $(RESOURCES_DOT_GO)

linux-386: $(RESOURCES_DOT_GO) $(SOURCES)
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=386 go build -a -o lantern_linux_386 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight/main

linux-amd64: $(RESOURCES_DOT_GO) $(SOURCES)
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -o lantern_linux_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight/main

linux-arm: $(RESOURCES_DOT_GO) $(SOURCES)
	@source setenv.bash && \
	HEADLESS=1 && \
	$(call build-tags) && \
	CGO_ENABLED=1 CC=arm-linux-gnueabi-gcc CXX=arm-linux-gnueabi-g++ CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=7 go build -a -o lantern_linux_arm -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight/main

windows: $(RESOURCES_DOT_GO) $(SOURCES)
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=windows GOARCH=386 go build -a -o lantern_windows_386.exe -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -H=windowsgui" github.com/getlantern/flashlight/main;

require-version:
	@if [[ -z "$$VERSION" ]]; then echo "VERSION environment value is required."; exit 1; fi

require-gh-token:
	@if [[ -z "$$GH_TOKEN" ]]; then echo "GH_TOKEN environment value is required."; exit 1; fi

require-secrets-dir:
	@if [[ -z "$$SECRETS_DIR" ]]; then echo "SECRETS_DIR environment value is required."; exit 1; fi

require-secrets: require-secrets-dir
	@if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi

$(BNS_CERT):
	@if [[ ! -r "$(BNS_CERT)" ]]; then echo "Missing $(BNS_CERT)" && exit 1; fi

require-lantern-binaries:
	@if [[ ! -d "$(LANTERN_BINARIES_PATH)" ]]; then \
		echo "Missing lantern binaries repository (https://github.com/getlantern/lantern-binaries). Set it with LANTERN_BINARIES_PATH=\"/path/to/repository\" make ..." && \
		exit 1; \
	fi

package-linux-386: require-version linux-386
	@cp lantern_linux_386 lantern_linux_i386;
	@$(call fpm-debian-build,"i386")
	@rm lantern_linux_i386;
	@mv update_linux_i386.bz2 update_linux_386.bz2 && \
	echo "-> lantern_$(VERSION)_i386.deb"

package-linux-amd64: require-version linux-amd64
	@$(call fpm-debian-build,"amd64")
	@echo "-> lantern_$(VERSION)_amd64.deb"

package-linux-arm: require-version linux-arm
	@$(call fpm-debian-build,"arm")
	@echo "-> lantern_$(VERSION)_arm.deb"

package-windows: $(BNS_CERT) require-version windows
	@if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	INSTALLER_RESOURCES="installer-resources/windows" && \
	rm -f $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	rm -f $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	cp installer-resources/$(PACKAGED_YAML) $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	cp $(LANTERN_YAML_PATH) $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	osslsigncode sign -pkcs12 "$(BNS_CERT)" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "lantern_windows_386.exe" -out "$$INSTALLER_RESOURCES/lantern.exe" && \
	cat $$INSTALLER_RESOURCES/lantern.exe | bzip2 > update_windows_386.bz2 && \
	ls -l lantern_windows_386.exe update_windows_386.bz2 && \
	makensis -V1 -DVERSION=$$VERSION installer-resources/windows/lantern.nsi && \
	osslsigncode sign -pkcs12 "$(BNS_CERT)" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "$$INSTALLER_RESOURCES/lantern-installer-unsigned.exe" -out "lantern-installer.exe" && \
	cp installer-resources/$(MANOTO_YAML) $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	cp $(LANTERN_YAML_PATH) $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	makensis -V1 -DVERSION=$$VERSION installer-resources/windows/lantern.nsi && \
	osslsigncode sign -pkcs12 "$(BNS_CERT)" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "$$INSTALLER_RESOURCES/lantern-installer-unsigned.exe" -out "lantern-installer-manoto.exe" && \
	echo "-> lantern-installer.exe and lantern-installer-manoto.exe"

linux: linux-386 linux-amd64

system-checks:
	@if [[ -z "$(DOCKER)" ]]; then echo 'Missing "docker" command.'; exit 1; fi && \
	if [[ -z "$(GO)" ]]; then echo 'Missing "go" command.'; exit 1; fi

require-s3cmd:
	@if [[ -z "$(S3CMD)" ]]; then echo 'Missing "s3cmd" command. Use "brew install s3cmd" or see https://github.com/s3tools/s3cmd/blob/master/INSTALL'; exit 1; fi

require-wget:
	@if [[ -z "$(WGET)" ]]; then echo 'Missing "wget" command.'; exit 1; fi

require-mercurial:
	@if [[ -z "$$(which hg 2> /dev/null)" ]]; then echo 'Missing "hg" command.'; exit 1; fi

require-appdmg:
	@if [[ -z "$(APPDMG)" ]]; then echo 'Missing "appdmg" command. Try sudo npm install -g appdmg.'; exit 1; fi

require-svgexport:
	@if [[ -z "$(SVGEXPORT)" ]]; then echo 'Missing "svgexport" command. Try sudo npm install -g svgexport.'; exit 1; fi

require-ruby:
	@if [[ -z "$(RUBY)" ]]; then echo 'Missing "ruby" command.'; exit 1; fi && \
	(gem which octokit >/dev/null) || (echo 'Missing gem "octokit". Try sudo gem install octokit.' && exit 1) && \
	(gem which mime-types >/dev/null) || (echo 'Missing gem "mime-types". Try sudo gem install mime-types.' && exit 1)

darwin: $(RESOURCES_DOT_GO) $(SOURCES)
	@echo "Building darwin/amd64..." && \
	export OSX_DEV_SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$(OSX_MIN_VERSION).sdk && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		source setenv.bash && \
		$(call build-tags) && \
		if [[ -d $$OSX_DEV_SDK ]]; then \
			export CGO_CFLAGS="--sysroot $$OSX_DEV_SDK" && \
			export CGO_LDFLAGS="--sysroot $$OSX_DEV_SDK"; \
		fi && \
		MACOSX_DEPLOYMENT_TARGET=$(OSX_MIN_VERSION) \
		CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build -a -o lantern_darwin_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -s" github.com/getlantern/flashlight/main; \
	else \
		echo "-> Skipped: Can not compile Lantern for OSX on a non-OSX host."; \
	fi

BUILD_RACE := '-race'

ifeq ($(OS),Windows_NT)
	  # Race detection is not supported by Go Windows 386, so disable it. The -x
		# is just a hack to allow us to pass something in place of -race below.
		BUILD_RACE = '-x'
endif

lantern: $(RESOURCES_DOT_GO) $(SOURCES)
	@echo "Building development lantern" && \
	$(call build-tags) && \
	source setenv.bash && \
	CGO_ENABLED=1 go build $(BUILD_RACE) -o lantern -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS_NOSTRIP) $$EXTRA_LDFLAGS" github.com/getlantern/flashlight/main; \

package-linux: require-version package-linux-386 package-linux-amd64

package-darwin-manoto: require-version require-appdmg require-svgexport darwin
	@echo "Generating distribution package for darwin/amd64 manoto..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		INSTALLER_RESOURCES="installer-resources/darwin" && \
		rm -rf Lantern.app && \
		cp -r $$INSTALLER_RESOURCES/Lantern.app_template Lantern.app && \
		sed -i '' "s/VERSION_STRING/$$VERSION.$(REVISION_DATE)/" Lantern.app/Contents/Info.plist && \
		mkdir Lantern.app/Contents/MacOS && \
		cp -r lantern_darwin_amd64 Lantern.app/Contents/MacOS/lantern && \
		mkdir Lantern.app/Contents/Resources/en.lproj && \
		cp installer-resources/$(MANOTO_YAML) Lantern.app/Contents/Resources/en.lproj/$(PACKAGED_YAML) && \
		cp $(LANTERN_YAML_PATH) Lantern.app/Contents/Resources/en.lproj/$(LANTERN_YAML) && \
		codesign --force -s "Developer ID Application: Brave New Software Project, Inc" -v Lantern.app && \
		cat Lantern.app/Contents/MacOS/lantern | bzip2 > update_darwin_amd64.bz2 && \
		ls -l lantern_darwin_amd64 update_darwin_amd64.bz2 && \
		rm -rf lantern-installer-manoto.dmg && \
		sed "s/__VERSION__/$$VERSION/g" $$INSTALLER_RESOURCES/dmgbackground.svg > $$INSTALLER_RESOURCES/dmgbackground_versioned.svg && \
		$(SVGEXPORT) $$INSTALLER_RESOURCES/dmgbackground_versioned.svg $$INSTALLER_RESOURCES/dmgbackground.png 600:400 && \
		sed "s/__VERSION__/$$VERSION/g" $$INSTALLER_RESOURCES/lantern.dmg.json > $$INSTALLER_RESOURCES/lantern_versioned.dmg.json && \
		$(APPDMG) --quiet $$INSTALLER_RESOURCES/lantern_versioned.dmg.json lantern-installer-manoto.dmg && \
		mv lantern-installer-manoto.dmg Lantern.dmg.zlib && \
		hdiutil convert -quiet -format UDBZ -o lantern-installer-manoto.dmg Lantern.dmg.zlib && \
		rm Lantern.dmg.zlib; \
	else \
		echo "-> Skipped: Can not generate a package on a non-OSX host."; \
	fi;

package-darwin: package-darwin-manoto
	@echo "Generating distribution package for darwin/amd64..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		INSTALLER_RESOURCES="installer-resources/darwin" && \
		rm -f Lantern.app/Contents/Resources/en.lproj/$(PACKAGED_YAML) && \
		rm -rf lantern-installer.dmg && \
		$(APPDMG) --quiet $$INSTALLER_RESOURCES/lantern_versioned.dmg.json lantern-installer.dmg && \
		mv lantern-installer.dmg Lantern.dmg.zlib && \
		hdiutil convert -quiet -format UDBZ -o lantern-installer.dmg Lantern.dmg.zlib && \
		rm Lantern.dmg.zlib; \
	else \
		echo "-> Skipped: Can not generate a package on a non-OSX host."; \
	fi;

binaries: docker-assets docker-linux docker-windows darwin

packages: require-version require-secrets clean-desktop clean-mobile docker-assets docker-package-windows docker-package-linux package-darwin package-android

# Override implicit docker-packages to avoid building whole packages target in
# docker, since it builds the pieces it needs in docker itself.
docker-packages: packages

release-qa: require-version require-s3cmd
	@BASE_NAME="lantern-installer-internal" && \
	BASE_NAME_MANOTO="lantern-installer-internal-manoto" && \
	rm -f $$BASE_NAME* && \
	cp lantern-installer.exe $$BASE_NAME.exe && \
	cp lantern-installer-manoto.exe $$BASE_NAME_MANOTO.exe && \
	cp lantern-installer.dmg $$BASE_NAME.dmg && \
	cp lantern-installer-manoto.dmg $$BASE_NAME_MANOTO.dmg && \
	cp lantern_*386.deb $$BASE_NAME-32-bit.deb && \
	cp lantern-manoto_*386.deb $$BASE_NAME_MANOTO-32-bit.deb && \
	cp lantern_*amd64.deb $$BASE_NAME-64-bit.deb && \
	cp lantern-manoto_*amd64.deb $$BASE_NAME_MANOTO-64-bit.deb && \
	cp lantern-installer.apk $$BASE_NAME.apk && \
	for NAME in $$(ls -1 $$BASE_NAME*.*); do \
		shasum -a 256 $$NAME | cut -d " " -f 1 > $$NAME.sha256 && \
		echo "Uploading SHA-256 `cat $$NAME.sha256`" && \
		$(S3CMD) put -P $$NAME.sha256 s3://$(S3_BUCKET) && \
		echo "Uploading $$NAME to S3" && \
		$(S3CMD) put -P $$NAME s3://$(S3_BUCKET) && \
		SUFFIX=$$(echo "$$NAME" | sed s/$$BASE_NAME//g) && \
		VERSIONED=lantern-installer-$$VERSION$$SUFFIX && \
		echo "Copying $$VERSIONED" && \
		$(S3CMD) cp s3://$(S3_BUCKET)/$$NAME s3://$(S3_BUCKET)/$$VERSIONED && \
		$(S3CMD) setacl s3://$(S3_BUCKET)/$$VERSIONED --acl-public; \
	done && \
	for NAME in update_darwin_amd64 update_linux_386 update_linux_amd64 update_windows_386 update_android_arm ; do \
	    mv $$NAME.bz2 $$NAME-$$VERSION.bz2 && \
		echo "Copying versioned name $$NAME-$$VERSION.bz2..." && \
		$(S3CMD) put -P $$NAME-$$VERSION.bz2 s3://$(S3_BUCKET); \
	done && \
	git tag -a "$$VERSION" -f --annotate -m"Tagged $$VERSION" && \
	git push --tags -f

release-beta: require-s3cmd
	@BASE_NAME="lantern-installer-internal" && \
	BETA_BASE_NAME="lantern-installer-beta" && \
	for URL in $$($(S3CMD) ls s3://$(S3_BUCKET)/ | grep $$BASE_NAME | awk '{print $$4}'); do \
		NAME=$$(basename $$URL) && \
		BETA=$$(echo $$NAME | sed s/"$$BASE_NAME"/$$BETA_BASE_NAME/) && \
		$(S3CMD) cp s3://$(S3_BUCKET)/$$NAME s3://$(S3_BUCKET)/$$BETA && \
		$(S3CMD) setacl s3://$(S3_BUCKET)/$$BETA --acl-public && \
		$(S3CMD) get --force s3://$(S3_BUCKET)/$$NAME $(LANTERN_BINARIES_PATH)/$$BETA; \
	done && \
	cd $(LANTERN_BINARIES_PATH) && \
	git add $$BETA_BASE_NAME* && \
	(git commit -am "Latest beta binaries for Lantern released from QA." && git push origin master) || true

release: require-version require-s3cmd require-gh-token require-wget require-ruby require-lantern-binaries
	@TAG_COMMIT=$$(git rev-list --abbrev-commit -1 $$VERSION) && \
	if [[ -z "$$TAG_COMMIT" ]]; then \
		echo "Could not find given tag $$VERSION."; \
	fi && \
	BASE_NAME="lantern-installer-beta" && \
	PROD_BASE_NAME="lantern-installer" && \
	for URL in $$($(S3CMD) ls s3://$(S3_BUCKET)/ | grep $$BASE_NAME | awk '{print $$4}'); do \
		NAME=$$(basename $$URL) && \
		PROD=$$(echo $$NAME | sed s/"$$BASE_NAME"/$$PROD_BASE_NAME/) && \
		$(S3CMD) cp s3://$(S3_BUCKET)/$$NAME s3://$(S3_BUCKET)/$$PROD && \
		$(S3CMD) setacl s3://$(S3_BUCKET)/$$PROD --acl-public && \
	    echo "Downloading released binary to $(LANTERN_BINARIES_PATH)/$$PROD" && \
	    $(S3CMD) get --force s3://$(S3_BUCKET)/$$PROD $(LANTERN_BINARIES_PATH)/$$PROD; \
	done && \
	$(RUBY) ./installer-resources/tools/createrelease.rb "$(GH_USER)" "$(GH_RELEASE_REPOSITORY)" $$VERSION && \
	for URL in $$($(S3CMD) ls s3://$(S3_BUCKET)/ | grep update_.*$$VERSION | awk '{print $$4}'); do \
		NAME=$$(basename $$URL) && \
		STRIPPED_NAME=$$(echo "$$NAME" | cut -d - -f 1).bz2 && \
		$(S3CMD) get --force s3://$(S3_BUCKET)/$$NAME $$STRIPPED_NAME && \
	    echo "Uploading $$STRIPPED_NAME for auto-updates" && \
	    $(RUBY) ./installer-resources/tools/uploadghasset.rb $(GH_USER) $(GH_RELEASE_REPOSITORY) $$VERSION $$STRIPPED_NAME; \
	done && \
	echo "Uploading released binaries to $(LANTERN_BINARIES_PATH)"
	@cd $(LANTERN_BINARIES_PATH) && \
	git pull && \
	git add $$PROD_BASE_NAME* && \
	(git commit -am "Latest binaries for Lantern $$VERSION ($$TAG_COMMIT)." && git push origin master) || true

update-resources:
	@(which go-bindata >/dev/null) || (echo 'Missing command "go-bindata". Sett https://github.com/jteeuwen/go-bindata.' && exit 1) && \
	go-bindata -nomemcopy -nocompress -pkg main -o src/github.com/getlantern/flashlight/icons.go -prefix \
	src/github.com/getlantern/flashlight/ src/github.com/getlantern/flashlight/icons && \
	go-bindata -nomemcopy -nocompress -pkg status -o src/github.com/getlantern/flashlight/status/resources.go -prefix \
	src/github.com/getlantern/flashlight/status_pages src/github.com/getlantern/flashlight/status_pages

create-tag: require-version
	@git tag -a "$$VERSION" -f --annotate -m"Tagged $$VERSION" && \
	git push --tags -f

# This target requires a file called testpackages.txt that lists all packages to
# test, one package per line, with no trailing newline on the last package.
# The -coverprofile flag is required to produce a profile for goveralls coverage
# reporting, and it only allows one package at a time, so we have to test each
# package individually. This dramatically slows down the tests, but is needed
# for coverage reporting. When simply testing locally, use make test instead.
test-and-cover: $(RESOURCES_DOT_GO)
	@echo "mode: count" > profile.cov && \
	source setenv.bash && \
	if [ -f envvars.bash ]; then \
		source envvars.bash; \
	fi && \
	TP=$$(cat testpackages.txt) && \
	CP=$$(echo -n $$TP | tr ' ', ',') && \
	for pkg in $$TP; do \
		go test -race -v -tags="headless" -covermode=atomic -coverpkg "$$CP" -coverprofile=profile_tmp.cov $$pkg || exit 1; \
		tail -n +2 profile_tmp.cov >> profile.cov; \
	done

test: $(RESOURCES_DOT_GO)
	@source setenv.bash && \
	if [ -f envvars.bash ]; then \
		source envvars.bash; \
	fi && \
	TP=$$(cat testpackages.txt) && \
	go test -race -v -tags="headless" $$TP || exit 1; \

genconfig:
	@echo "Running genconfig..." && \
	source setenv.bash && \
	(cd src/github.com/getlantern/flashlight/genconfig && ./genconfig.bash)

bin/gomobile:
	@source setenv.bash && \
	go install golang.org/x/mobile/cmd/gomobile

pkg/gomobile: bin/gomobile
	@source setenv.bash && \
	gomobile init

$(ANDROID_LIB): bin/gomobile pkg/gomobile
	@source setenv.bash && \
	$(call build-tags) && \
	gomobile bind -target=android/arm -tags='headless' -o=$(ANDROID_LIB) -ldflags="$(LDFLAGS) $$EXTRA_LDFLAGS -s" $(ANDROID_LIB_PKG)

android-lib: $(ANDROID_LIB)

$(ANDROID_SDK_ANDROID_LIB): $(ANDROID_LIB)
	mkdir -p $(ANDROID_SDK_LIBS) && \
	cp $(ANDROID_LIB) $(ANDROID_SDK_ANDROID_LIB)

$(ANDROID_SDK): $(ANDROID_SDK_ANDROID_LIB)
	(cd $(ANDROID_SDK_DIR) && gradle assembleDebug)

android-sdk: $(ANDROID_SDK)

$(PUBSUB_JAVA):
	@(cd $(PUBSUB_JAVA_DIR) && gradle shadowJar)

$(PUBSUB_PUBSUB_JAVA_LIB): $(PUBSUB_JAVA)
	@mkdir -p $(PUBSUB_LIBS) && \
	cp $(PUBSUB_JAVA) $(PUBSUB_PUBSUB_JAVA_LIB)

$(PUBSUB): $(PUBSUB_PUBSUB_JAVA_LIB)
	@(cd $(PUBSUB_DIR) && gradle assembleDebug)

$(ANDROID_TESTBED_ANDROID_LIB): $(ANDROID_LIB)
	@mkdir -p $(ANDROID_TESTBED_LIBS) && \
	cp $(ANDROID_LIB) $(ANDROID_TESTBED_ANDROID_LIB)

$(ANDROID_TESTBED_ANDROID_SDK): $(ANDROID_SDK)
	@mkdir -p $(ANDROID_TESTBED_LIBS) && \
	cp $(ANDROID_SDK) $(ANDROID_TESTBED_ANDROID_SDK)

$(ANDROID_TESTBED_PUBSUB): $(PUBSUB)
	@mkdir -p $(ANDROID_TESTBED_LIBS) && \
	cp $(PUBSUB) $(ANDROID_TESTBED_PUBSUB)

$(ANDROID_TESTBED): $(ANDROID_TESTBED_ANDROID_LIB) $(ANDROID_TESTBED_ANDROID_SDK) $(ANDROID_TESTBED_PUBSUB)
	@cd $(ANDROID_TESTBED_DIR)/app
	gradle -b $(ANDROID_TESTBED_DIR)/app/build.gradle \
		clean \
		assembleDebug

android-testbed: $(ANDROID_TESTBED)

android-testbed-install: $(ANDROID_TESTBED)
	adb install -r $(ANDROID_TESTBED)

$(TUN2SOCKS):
	@cd $(LANTERN_MOBILE_DIR) && ndk-build

$(LANTERN_MOBILE_TUN2SOCKS): $(TUN2SOCKS)
	@mkdir -p $(LANTERN_MOBILE_ARM_LIBS) && \
	cp $(TUN2SOCKS) $(LANTERN_MOBILE_TUN2SOCKS)

$(LANTERN_MOBILE_ANDROID_LIB): $(ANDROID_LIB)
	@mkdir -p $(LANTERN_MOBILE_LIBS) && \
	cp $(ANDROID_LIB) $(LANTERN_MOBILE_ANDROID_LIB)

$(LANTERN_MOBILE_ANDROID_SDK): $(ANDROID_SDK)
	@mkdir -p $(LANTERN_MOBILE_LIBS) && \
	cp $(ANDROID_SDK) $(LANTERN_MOBILE_ANDROID_SDK)

$(LANTERN_MOBILE_PUBSUB): $(PUBSUB)
	@mkdir -p $(LANTERN_MOBILE_LIBS) && \
	cp $(PUBSUB) $(LANTERN_MOBILE_PUBSUB)

$(LANTERN_MOBILE_ANDROID_DEBUG): $(LANTERN_MOBILE_TUN2SOCKS) $(LANTERN_MOBILE_ANDROID_LIB) $(LANTERN_MOBILE_ANDROID_SDK) $(LANTERN_MOBILE_PUBSUB)
	@gradle -PlanternVersion=$(GIT_REVISION) -PlanternRevisionDate=$(REVISION_DATE) -b $(LANTERN_MOBILE_DIR)/app/build.gradle \
		clean \
		assembleDebug

$(LANTERN_MOBILE_ANDROID_RELEASE): $(LANTERN_MOBILE_TUN2SOCKS) $(LANTERN_MOBILE_ANDROID_LIB) $(LANTERN_MOBILE_ANDROID_SDK) $(LANTERN_MOBILE_PUBSUB)
	@echo "Generating distribution package for android..."
	ln -f -s $$SECRETS_DIR/android/keystore.release.jks $(LANTERN_MOBILE_DIR)/app && \
	gradle -PlanternVersion=$$VERSION -PlanternRevisionDate=$(REVISION_DATE) -b $(LANTERN_MOBILE_DIR)/app/build.gradle \
		clean \
		assembleRelease && \
	cp $(LANTERN_MOBILE_ANDROID_RELEASE) lantern-installer.apk;

android-debug: $(LANTERN_MOBILE_ANDROID_DEBUG)

android-release: require-version require-secrets-dir $(LANTERN_MOBILE_ANDROID_RELEASE)

android-install: $(LANTERN_MOBILE_ANDROID_DEBUG)
	adb install -r $(LANTERN_MOBILE_ANDROID_DEBUG)

clean-assets:
	rm -f $(RESOURCES_DOT_GO)

package-android: require-version require-secrets-dir $(LANTERN_MOBILE_ANDROID_RELEASE)
	cat lantern-installer.apk | bzip2 > update_android_arm.bz2 && \
	echo "-> lantern-installer.apk"

# Provided for backward compatibility with how people used to use the makefile
update-dist: clean-assets assets

# Executes whatever command is in the CMD environment variable. This is useful
# when you want to test something in docker, e.g.
#   CMD="go test github.com/getlantern/byteexec" make docker-exec
exec:
	@source setenv.bash && \
	eval $$CMD

clean-desktop: clean-assets
	rm -f lantern && \
	rm -f lantern_linux* && \
	rm -f lantern_darwin* && \
	rm -f lantern_windows* && \
	rm -f lantern-installer* && \
	rm -f update_* && \
	rm -f *.deb && \
	rm -f *.png && \
	rm -rf *.app && \
	rm -f src/github.com/getlantern/flashlight/*.syso && \
	rm -f *.dmg && \
	rm -f $(LANTERN_MOBILE_TUN2SOCKS) && \
	rm -rf $(LANTERN_MOBILE_DIR)/libs/armeabi*

clean-mobile:
	rm -f $(ANDROID_LIB) && \
	rm -f $(ANDROID_SDK_ANDROID_LIB) && \
	rm -f $(ANDROID_SDK) && \
	rm -f $(PUBSUB_JAVA) && \
	rm -f $(PUBSUB) && \
	rm -f $(ANDROID_TESTBED_ANDROID_LIB) && \
	rm -f $(ANDROID_TESTBED_ANDROID_SDK) && \
	rm -f $(ANDROID_TESTBED_PUBSUB) && \
	rm -f $(ANDROID_TESTBED) && \
	rm -f $(LANTERN_MOBILE_ANDROID_LIB) && \
	rm -f $(LANTERN_MOBILE_ANDROID_SDK) && \
	rm -f $(LANTERN_MOBILE_ANDROID_DEBUG) && \
	rm -f $(LANTERN_MOBILE_ANDROID_RELEASE)

clean-tooling:
	rm -rf bin && \
	rm -rf pkg

clean: clean-tooling clean-desktop clean-mobile
