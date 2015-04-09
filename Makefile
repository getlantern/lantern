SHELL := /bin/bash

DOCKER := $(shell which docker 2> /dev/null);
GO := $(shell which go 2> /dev/null)
NODE := $(shell which node 2> /dev/null)
NPM := $(shell which npm 2> /dev/null)

BOOT2DOCKER := $(shell which boot2docker 2> /dev/null)

BUILD_DATE := $(shell date -u +%Y%m%d.%H%M%S)
GIT_REVISION := $(shell git describe --abbrev=0 --tags --exact-match 2> /dev/null || git rev-parse --short HEAD)
LOGGLY_TOKEN := 469973d5-6eaf-445a-be71-cf27141316a1
LDFLAGS := -w -X main.version $(GIT_REVISION) -X main.buildDate $(BUILD_DATE) -X github.com/getlantern/flashlight/logging.logglyToken \"$(LOGGLY_TOKEN)\"
LANTERN_DESCRIPTION := Censorship circumvention tool
LANTERN_EXTENDED_DESCRIPTION := Lantern allows you to access sites blocked by internet censorship.\nWhen you run it, Lantern reroutes traffic to selected domains through servers located where such domains aren't censored.

PACKAGE_VENDOR := Brave New Software Project, Inc
PACKAGE_MAINTAINER := Lantern Team <team@getlantern.org>
PACKAGE_URL := https://www.getlantern.org

DOCKER_IMAGE_TAG := flashlight-builder

.PHONY: packages clean docker

define build-tags
	BUILD_TAGS="" && \
	if [[ ! -z "$$VERSION" ]]; then \
		BUILD_TAGS="prod" && \
		sed s/'packageVersion.*'/'packageVersion = "'$$VERSION'"'/ src/github.com/getlantern/flashlight/autoupdate.go | sed s/'!prod'/'prod'/ > src/github.com/getlantern/flashlight/autoupdate-prod.go; \
	else \
		echo "** VERSION was not set, using git revision instead ($(GIT_REVISION)). This is OK while in development."; \
	fi && \
	if [[ ! -z "$$HEADLESS" ]]; then \
		BUILD_TAGS="$$BUILD_TAGS headless"; \
	fi && \
	BUILD_TAGS=$$(echo $$BUILD_TAGS | xargs) && \
	echo "Build tags: $$BUILD_TAGS"
endef

define docker-up
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		if [[ -z "$(BOOT2DOCKER)" ]]; then \
			echo 'Missing "boot2docker" command' && exit 1; \
		fi && \
		if [[ "$$($(BOOT2DOCKER) status)" != "running" ]]; then \
			$(BOOT2DOCKER) up; \
		fi && \
		if [[ -z "$$DOCKER_HOST" ]]; then \
			$$($(BOOT2DOCKER) shellinit 2>/dev/null); \
		fi \
	fi
endef

define fpm-debian-build =
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
	\
	fpm -a $$PKG_ARCH -s dir -t deb -n lantern -v $$VERSION -m "$(PACKAGE_MAINTAINER)" --description "$(LANTERN_DESCRIPTION)\n$(LANTERN_EXTENDED_DESCRIPTION)" --category net --license "Apache-2.0" --vendor "$(PACKAGE_VENDOR)" --url $(PACKAGE_URL) --deb-compression xz -f -C $$WORKDIR usr;
endef

all: binaries

# This is to be called within the docker image.
docker-genassets:
	@source setenv.bash && \
	LANTERN_UI="src/github.com/getlantern/lantern-ui" && \
	APP="$$LANTERN_UI/app" && \
	DIST="$$LANTERN_UI/dist" && \
	DEST="src/github.com/getlantern/flashlight/ui/resources.go" && \
	\
	if [ "$$UPDATE_DIST" ]; then \
			cd $$LANTERN_UI && \
			npm install && \
			rm -Rf dist && \
			gulp build && \
			cd -; \
	fi && \
	\
	rm -f bin/tarfs bin/rsrc && \
	go install github.com/getlantern/tarfs/tarfs && \
	echo "// +build prod" > $$DEST && \
	echo " " >> $$DEST && \
	tarfs -pkg ui $$DIST >> $$DEST && \
	go install github.com/akavel/rsrc && \
	rsrc -ico installer-resources/windows/lantern.ico -o src/github.com/getlantern/flashlight/lantern.syso;

docker-linux-amd64:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o lantern_linux_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

docker-linux-386:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=386 go build -o lantern_linux_386 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

docker-windows-386:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=windows GOARCH=386 go build -o lantern_windows_386.exe -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -H=windowsgui" github.com/getlantern/flashlight;

require-version:
	@if [[ -z "$$VERSION" ]]; then echo "VERSION environment value is required."; exit 1; fi

require-secrets:
	@if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	if [[ -z "$$SECRETS_DIR" ]]; then echo "SECRETS_DIR environment value is required."; exit 1; fi

docker-package-linux-386: docker-linux-386 docker-package-debian-386

docker-package-linux-amd64: docker-linux-amd64 docker-package-debian-amd64

docker-package-debian-386: require-version docker-linux-386
	@cp lantern_linux_386 lantern_linux_i386;
	@$(call fpm-debian-build,"i386")
	@rm lantern_linux_i386 && \
	echo "-> lantern_$(VERSION)_i386.deb"

docker-package-debian-amd64: require-version docker-linux-amd64
	@$(call fpm-debian-build,"amd64")
	@echo "-> lantern_$(VERSION)_amd64.deb"

docker-package-windows: require-version docker-windows-386
	@if [[ -z "$$BNS_CERT" ]]; then echo "BNS_CERT environment value is required."; exit 1; fi && \
	if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	INSTALLER_RESOURCES="installer-resources/windows" && \
	osslsigncode sign -pkcs12 "$$BNS_CERT" -pass "$$BNS_CERT_PASS" -in "lantern_windows_386.exe" -out "$$INSTALLER_RESOURCES/lantern.exe" && \
	makensis -V1 -DVERSION=$$VERSION installer-resources/windows/lantern.nsi && \
	osslsigncode sign -pkcs12 "$$BNS_CERT" -pass "$$BNS_CERT_PASS" -in "$$INSTALLER_RESOURCES/lantern-installer-unsigned.exe" -out "lantern-installer.exe";

docker: system-checks
	@$(call docker-up) && \
	DOCKER_CONTEXT=.$(DOCKER_IMAGE_TAG)-context && \
	mkdir -p $$DOCKER_CONTEXT && \
	cp Dockerfile $$DOCKER_CONTEXT && \
	docker build -t $(DOCKER_IMAGE_TAG) $$DOCKER_CONTEXT;

linux: genassets linux-386 linux-amd64

windows: genassets windows-386

darwin: genassets darwin-amd64

system-checks:
	@if [[ -z "$(DOCKER)" ]]; then echo 'Missing "docker" command.'; exit 1; fi && \
	if [[ -z "$(GO)" ]]; then echo 'Missing "go" command.'; exit 1; fi

genassets:
	@echo "Generating assets..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && make docker-genassets' && \
	echo "OK"

linux-amd64:
	@echo "Building linux/amd64..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-linux-amd64' && \
	cat lantern_linux_amd64 | bzip2 > update_linux_amd64.bz2 && \
	ls -l lantern_linux_amd64 update_linux_amd64.bz2

linux-386:
	@echo "Building linux/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-linux-386' && \
	cat lantern_linux_386 | bzip2 > update_linux_386.bz2 && \
	ls -l lantern_linux_386 update_linux_386.bz2

windows-386:
	@echo "Building windows/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-windows-386' && \
	cat lantern_windows_386.exe | bzip2 > update_windows_386.bz2 && \
	ls -l lantern_windows_386.exe update_windows_386.bz2

darwin-amd64:
	@echo "Building darwin/amd64..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		source setenv.bash && \
		$(call build-tags) && \
		CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build -o lantern_darwin_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS)" github.com/getlantern/flashlight && \
		cat lantern_darwin_amd64 | bzip2 > update_darwin_amd64.bz2 && \
		ls -l lantern_darwin_amd64 update_darwin_amd64.bz2; \
	else \
		echo "-> Skipped: Can not compile Lantern for OSX on a non-OSX host."; \
	fi;

package-linux-386: require-version linux-386
	@echo "Generating distribution package for linux/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && VERSION="'$$VERSION'" make docker-package-linux-386'

package-linux-amd64: require-version linux-amd64
	@echo "Generating distribution package for linux/amd64..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && VERSION="'$$VERSION'" make docker-package-linux-amd64'

package-linux: require-version package-linux-386 package-linux-amd64

package-windows: require-version windows-386
	@echo "Generating distribution package for windows/386..." && \
	if [[ -z "$$SECRETS_DIR" ]]; then echo "SECRETS_DIR environment value is required."; exit 1; fi && \
	if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	$(call docker-up) && \
	docker run -v $$PWD:/flashlight-build -v $$SECRETS_DIR:/secrets -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /flashlight-build && BNS_CERT="/secrets/bns_cert.p12" BNS_CERT_PASS="'$$BNS_CERT_PASS'" VERSION="'$$VERSION'" make docker-package-windows' && \
	echo "-> lantern-installer.exe"

package-darwin: require-version darwin
	@echo "Generating distribution package for darwin/amd64..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		if [[ -z "$(NODE)" ]]; then echo 'Missing "node" command.'; exit 1; fi && \
		if [[ -z "$(NPM)" ]]; then echo 'Missing "npm" command.'; exit 1; fi && \
		INSTALLER_RESOURCES="installer-resources/darwin" && \
		APPDMG=$$(which appdmg) && \
		SVGEXPORT=$$(which svgexport) && \
		if [[ -z "$$APPDMG" ]]; then npm install -g appdmg; fi && \
		if [[ -z "$$SVGEXPORT" ]]; then npm install -g svgexport; fi && \
		rm -rf Lantern.app && \
		cp -r $$INSTALLER_RESOURCES/Lantern.app_template Lantern.app && \
		cp -r lantern_darwin_amd64 Lantern.app/Contents/MacOS/lantern && \
		codesign -s "Developer ID Application: $$PACKAGE_VENDOR" Lantern.app && \
		rm -rf Lantern.dmg && \
		sed "s/__VERSION__/$$VERSION/g" $$INSTALLER_RESOURCES/dmgbackground.svg > dmgbackground_versioned.svg && \
		$$SVGEXPORT dmgbackground_versioned.svg dmgbackground.png 600:400 && \
		$$APPDMG --quiet $$INSTALLER_RESOURCES/lantern.dmg.json Lantern.dmg && \
		mv Lantern.dmg Lantern.dmg.zlib && \
		hdiutil convert -quiet -format UDBZ -o Lantern.dmg Lantern.dmg.zlib && \
		rm Lantern.dmg.zlib; \
	else \
		echo "-> Skipped: Can not generate a package on a non-OSX host."; \
	fi;

binaries: docker genassets linux windows darwin

packages: require-version require-secrets clean binaries package-windows package-linux package-darwin

clean:
	@rm -f lantern_linux*
	@rm -f lantern_darwin*
	@rm -f lantern_windows*
	@rm -f *.deb
	@rm -rf *.app
	@rm -f *.dmg
