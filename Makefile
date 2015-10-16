SHELL := /bin/bash

DOCKER := $(shell which docker 2> /dev/null)
GO := $(shell which go 2> /dev/null)
NODE := $(shell which node 2> /dev/null)
NPM := $(shell which npm 2> /dev/null)
S3CMD := $(shell which s3cmd 2> /dev/null)
WGET := $(shell which wget 2> /dev/null)
RUBY := $(shell which ruby 2> /dev/null)

APPDMG := $(shell which appdmg 2> /dev/null)
SVGEXPORT := $(shell which svgexport 2> /dev/null)

BOOT2DOCKER := $(shell which boot2docker 2> /dev/null)

GIT_REVISION_SHORTCODE := $(shell git rev-parse --short HEAD)
GIT_REVISION := $(shell git describe --abbrev=0 --tags --exact-match 2> /dev/null || git rev-parse --short HEAD)
GIT_REVISION_DATE := $(shell git show -s --format=%ci $(GIT_REVISION_SHORTCODE))

REVISION_DATE := $(shell date -u -j -f "%F %T %z" "$(GIT_REVISION_DATE)" +"%Y%m%d.%H%M%S" 2>/dev/null || date -u -d "$(GIT_REVISION_DATE)" +"%Y%m%d.%H%M%S")
BUILD_DATE := $(shell date -u +%Y%m%d.%H%M%S)

LOGGLY_TOKEN := 2b68163b-89b6-4196-b878-c1aca4bbdf84 

LDFLAGS := -w -X=main.version=$(GIT_REVISION) -X=main.revisionDate=$(REVISION_DATE) -X=main.buildDate=$(BUILD_DATE) -X=github.com/getlantern/flashlight/logging.logglyToken=$(LOGGLY_TOKEN)
LANTERN_DESCRIPTION := Censorship circumvention tool
LANTERN_EXTENDED_DESCRIPTION := Lantern allows you to access sites blocked by internet censorship.\nWhen you run it, Lantern reroutes traffic to selected domains through servers located where such domains are uncensored.

PACKAGE_VENDOR := Brave New Software Project, Inc
PACKAGE_MAINTAINER := Lantern Team <team@getlantern.org>
PACKAGE_URL := https://www.getlantern.org
PACKAGED_YAML := .packaged-lantern.yaml
MANOTO_YAML := .packaged-lantern-manoto.yaml

LANTERN_BINARIES_PATH ?= ../lantern-binaries

GH_USER ?= getlantern

GH_RELEASE_REPOSITORY ?= lantern

S3_BUCKET ?= lantern

DOCKER_IMAGE_TAG := lantern-builder

LANTERN_MOBILE_DIR := src/github.com/getlantern/lantern-mobile
LANTERN_MOBILE_LIBRARY := libflashlight.aar
DOCKER_MOBILE_IMAGE_TAG := lantern-mobile-builder
LOGGLY_TOKEN_MOBILE := d730c074-1f0a-415d-8d71-1ebf1d8bd736

FIRETWEET_MAIN_DIR ?= ../firetweet/firetweet/src/main/

LANTERN_YAML := lantern.yaml
LANTERN_YAML_PATH := installer-resources/lantern.yaml

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
	BUILD_TAGS=$$(echo $$BUILD_TAGS | xargs) && echo "Build tags: $$BUILD_TAGS"
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

all: binaries

# This is to be called within the docker image.
docker-genassets: require-npm
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
	echo "// +build !stub" > $$DEST && \
	echo " " >> $$DEST && \
	tarfs -pkg ui $$DIST >> $$DEST && \
	go install github.com/akavel/rsrc && \
	rsrc -ico installer-resources/windows/lantern.ico -o src/github.com/getlantern/flashlight/lantern_windows_386.syso;

docker-linux-386:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=386 go build -a -o lantern_linux_386 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

docker-linux-amd64:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -a -o lantern_linux_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

docker-linux-arm:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 CC=arm-linux-gnueabi-gcc CXX=arm-linux-gnueabi-g++ CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=7 go build -a -o lantern_linux_arm -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

docker-windows-386:
	@source setenv.bash && \
	$(call build-tags) && \
	CGO_ENABLED=1 GOOS=windows GOARCH=386 go build -a -o lantern_windows_386.exe -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS) -H=windowsgui" github.com/getlantern/flashlight;

require-assets:
	@if [ ! -f ./src/github.com/getlantern/flashlight/ui/resources.go ]; then make genassets; fi

require-version:
	@if [[ -z "$$VERSION" ]]; then echo "VERSION environment value is required."; exit 1; fi

require-gh-token:
	@if [[ -z "$$GH_TOKEN" ]]; then echo "GH_TOKEN environment value is required."; exit 1; fi

require-secrets:
	@if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	if [[ -z "$$SECRETS_DIR" ]]; then echo "SECRETS_DIR environment value is required."; exit 1; fi

require-lantern-binaries:
	@if [[ ! -d "$(LANTERN_BINARIES_PATH)" ]]; then \
		echo "Missing lantern binaries repository (https://github.com/getlantern/lantern-binaries). Set it with LANTERN_BINARIES_PATH=\"/path/to/repository\" make ..." && \
		exit 1; \
	fi

docker-package-debian-386: require-version docker-linux-386
	@cp lantern_linux_386 lantern_linux_i386;
	@$(call fpm-debian-build,"i386")
	@rm lantern_linux_i386;
	@mv update_linux_i386.bz2 update_linux_386.bz2 && \
	echo "-> lantern_$(VERSION)_i386.deb"

docker-package-debian-amd64: require-version docker-linux-amd64
	@$(call fpm-debian-build,"amd64")
	@echo "-> lantern_$(VERSION)_amd64.deb"

docker-package-debian-arm: require-version docker-linux-arm
	@$(call fpm-debian-build,"arm")
	@echo "-> lantern_$(VERSION)_arm.deb"

docker-package-windows: require-version docker-windows-386
	@if [[ -z "$$BNS_CERT" ]]; then echo "BNS_CERT environment value is required."; exit 1; fi && \
	if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	INSTALLER_RESOURCES="installer-resources/windows" && \
	rm -f $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	rm -f $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	cp installer-resources/$(PACKAGED_YAML) $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	cp $(LANTERN_YAML_PATH) $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	osslsigncode sign -pkcs12 "$$BNS_CERT" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "lantern_windows_386.exe" -out "$$INSTALLER_RESOURCES/lantern.exe" && \
	cat $$INSTALLER_RESOURCES/lantern.exe | bzip2 > update_windows_386.bz2 && \
	ls -l lantern_windows_386.exe update_windows_386.bz2 && \
	makensis -V1 -DVERSION=$$VERSION installer-resources/windows/lantern.nsi && \
	osslsigncode sign -pkcs12 "$$BNS_CERT" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "$$INSTALLER_RESOURCES/lantern-installer-unsigned.exe" -out "lantern-installer.exe" && \
	cp installer-resources/$(MANOTO_YAML) $$INSTALLER_RESOURCES/$(PACKAGED_YAML) && \
	cp $(LANTERN_YAML_PATH) $$INSTALLER_RESOURCES/$(LANTERN_YAML) && \
	makensis -V1 -DVERSION=$$VERSION installer-resources/windows/lantern.nsi && \
	osslsigncode sign -pkcs12 "$$BNS_CERT" -pass "$$BNS_CERT_PASS" -n "Lantern" -t http://timestamp.verisign.com/scripts/timstamp.dll -in "$$INSTALLER_RESOURCES/lantern-installer-unsigned.exe" -out "lantern-installer-manoto.exe";

docker: system-checks
	@$(call docker-up) && \
	DOCKER_CONTEXT=.$(DOCKER_IMAGE_TAG)-context && \
	mkdir -p $$DOCKER_CONTEXT && \
	cp Dockerfile $$DOCKER_CONTEXT && \
	docker build -t $(DOCKER_IMAGE_TAG) $$DOCKER_CONTEXT;

docker-mobile:
	@$(call docker-up) && \
	DOCKER_CONTEXT=.$(DOCKER_MOBILE_IMAGE_TAG)-context && \
	mkdir -p $$DOCKER_CONTEXT && \
	cp $(LANTERN_MOBILE_DIR)/Dockerfile $$DOCKER_CONTEXT && \
	docker build -t $(DOCKER_MOBILE_IMAGE_TAG) $$DOCKER_CONTEXT

linux: genassets linux-386 linux-amd64 

windows: genassets windows-386

darwin: genassets darwin-amd64

system-checks:
	@if [[ -z "$(DOCKER)" ]]; then echo 'Missing "docker" command.'; exit 1; fi && \
	if [[ -z "$(GO)" ]]; then echo 'Missing "go" command.'; exit 1; fi

require-s3cmd:
	@if [[ -z "$(S3CMD)" ]]; then echo 'Missing "s3cmd" command. Use "brew install s3cmd" or see https://github.com/s3tools/s3cmd/blob/master/INSTALL'; exit 1; fi

require-wget:
	@if [[ -z "$(WGET)" ]]; then echo 'Missing "wget" command.'; exit 1; fi

require-mercurial:
	@if [[ -z "$$(which hg 2> /dev/null)" ]]; then echo 'Missing "hg" command.'; exit 1; fi

require-node:
	@if [[ -z "$(NODE)" ]]; then echo 'Missing "node" command.'; exit 1; fi

require-npm: require-node
	@if [[ -z "$(NPM)" ]]; then echo 'Missing "npm" command.'; exit 1; fi

require-appdmg:
	@if [[ -z "$(APPDMG)" ]]; then echo 'Missing "appdmg" command. Try sudo npm install -g appdmg.'; exit 1; fi

require-svgexport:
	@if [[ -z "$(SVGEXPORT)" ]]; then echo 'Missing "svgexport" command. Try sudo npm install -g svgexport.'; exit 1; fi

require-ruby:
	@if [[ -z "$(RUBY)" ]]; then echo 'Missing "ruby" command.'; exit 1; fi && \
	(gem which octokit >/dev/null) || (echo 'Missing gem "octokit". Try sudo gem install octokit.' && exit 1) && \
	(gem which mime-types >/dev/null) || (echo 'Missing gem "mime-types". Try sudo gem install mime-types.' && exit 1)

genassets: docker
	@echo "Generating assets..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c "cd /lantern && UPDATE_DIST=$$UPDATE_DIST make docker-genassets" && \
	git update-index --assume-unchanged src/github.com/getlantern/flashlight/ui/resources.go && \
	echo "OK"

linux-386: require-assets docker
	@echo "Building linux/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-linux-386'

linux-amd64: require-assets docker
	@echo "Building linux/amd64..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-linux-amd64'

linux-arm: require-assets docker
	@echo "Building linux/arm..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" HEADLESS="1" make docker-linux-arm'

windows-386: require-assets docker
	@echo "Building windows/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" HEADLESS="'$$HEADLESS'" make docker-windows-386'

darwin-amd64: require-assets
	@echo "Building darwin/amd64..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		source setenv.bash && \
		$(call build-tags) && \
		CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build -a -o lantern_darwin_amd64 -tags="$$BUILD_TAGS" -ldflags="$(LDFLAGS)" github.com/getlantern/flashlight; \
	else \
		echo "-> Skipped: Can not compile Lantern for OSX on a non-OSX host."; \
	fi

package-linux-386: require-version genassets linux-386
	@echo "Generating distribution package for linux/386..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" make docker-package-debian-386'

package-linux-amd64: require-version genassets linux-amd64
	@echo "Generating distribution package for linux/amd64..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" make docker-package-debian-amd64'

package-linux-arm: require-version genassets linux-arm
	@echo "Generating distribution package for linux/arm..." && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && VERSION="'$$VERSION'" HEADLESS="1" make docker-package-debian-arm'

package-linux: require-version package-linux-386 package-linux-amd64

package-windows: require-version windows
	@echo "Generating distribution package for windows/386..." && \
	if [[ -z "$$SECRETS_DIR" ]]; then echo "SECRETS_DIR environment value is required."; exit 1; fi && \
	if [[ -z "$$BNS_CERT_PASS" ]]; then echo "BNS_CERT_PASS environment value is required."; exit 1; fi && \
	$(call docker-up) && \
	docker run -v $$PWD:/lantern -v $$SECRETS_DIR:/secrets -t $(DOCKER_IMAGE_TAG) /bin/bash -c 'cd /lantern && BNS_CERT="/secrets/bns.pfx" BNS_CERT_PASS="'$$BNS_CERT_PASS'" VERSION="'$$VERSION'" make docker-package-windows' && \
	echo "-> lantern-installer.exe and lantern-installer-manoto.exe"

package-darwin-manoto: require-version require-appdmg require-svgexport darwin
	@echo "Generating distribution package for darwin/amd64 manoto..." && \
	if [[ "$$(uname -s)" == "Darwin" ]]; then \
		INSTALLER_RESOURCES="installer-resources/darwin" && \
		rm -rf Lantern.app && \
		cp -r $$INSTALLER_RESOURCES/Lantern.app_template Lantern.app && \
		mkdir Lantern.app/Contents/MacOS && \
		cp -r lantern_darwin_amd64 Lantern.app/Contents/MacOS/lantern && \
		mkdir Lantern.app/Contents/Resources/en.lproj && \
		cp installer-resources/$(MANOTO_YAML) Lantern.app/Contents/Resources/en.lproj/$(PACKAGED_YAML) && \
		cp $(LANTERN_YAML_PATH) Lantern.app/Contents/Resources/en.lproj/$(LANTERN_YAML) && \
		codesign -s "Developer ID Application: Brave New Software Project, Inc" Lantern.app && \
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

binaries: docker genassets linux windows darwin

packages: require-version require-secrets clean binaries package-windows package-linux package-darwin

release-qa: require-version require-s3cmd
	@BASE_NAME="lantern-installer-qa" && \
	BASE_NAME_MANOTO="lantern-installer-qa-manoto" && \
	rm -f $$BASE_NAME* && \
	cp lantern-installer.exe $$BASE_NAME.exe && \
	cp lantern-installer-manoto.exe $$BASE_NAME_MANOTO.exe && \
	cp lantern-installer.dmg $$BASE_NAME.dmg && \
	cp lantern-installer-manoto.dmg $$BASE_NAME_MANOTO.dmg && \
	cp lantern_*386.deb $$BASE_NAME-32-bit.deb && \
	cp lantern-manoto_*386.deb $$BASE_NAME_MANOTO-32-bit.deb && \
	cp lantern_*amd64.deb $$BASE_NAME-64-bit.deb && \
	cp lantern-manoto_*amd64.deb $$BASE_NAME_MANOTO-64-bit.deb && \
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
	done && \
	for NAME in update_darwin_amd64 update_linux_386 update_linux_amd64 update_windows_386 ; do \
	    mv $$NAME.bz2 $$NAME-$$VERSION.bz2 && \
		echo "Copying versioned name $$NAME-$$VERSION.bz2..." && \
		$(S3CMD) put -P $$NAME-$$VERSION.bz2 s3://$(S3_BUCKET); \
	done && \
	git tag -a "$$VERSION" -f --annotate -m"Tagged $$VERSION" && \
	git push --tags -f

release-beta: require-s3cmd
	@BASE_NAME="lantern-installer-qa" && \
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

test-and-cover:
	@echo "mode: count" > profile.cov && \
	source setenv.bash && \
	if [ -f envvars.bash ]; then \
		source envvars.bash; \
	fi && \
	for pkg in $$(cat testpackages.txt); do \
		go test -v -covermode=count -coverprofile=profile_tmp.cov $$pkg || exit 1; \
		tail -n +2 profile_tmp.cov >> profile.cov; \
	done

genconfig:
	@echo "Running genconfig..." && \
	source setenv.bash && \
	(cd src/github.com/getlantern/flashlight/genconfig && ./genconfig.bash)

android-lib: docker-mobile
	@source setenv.bash && \
	cd $(LANTERN_MOBILE_DIR)
	@$(call docker-up) && \
	$(DOCKER) run -v $$PWD/src:/src $(DOCKER_MOBILE_IMAGE_TAG) /bin/bash -c \ "cd /src/github.com/getlantern/lantern-mobile && gomobile bind -target=android -o=$(LANTERN_MOBILE_LIBRARY) -ldflags="$(LDFLAGS)" ." && \
	if [ -d "$(FIRETWEET_MAIN_DIR)" ]; then \
		cp -v $(LANTERN_MOBILE_DIR)/$(LANTERN_MOBILE_LIBRARY) $(FIRETWEET_MAIN_DIR)/libs/$(LANTERN_MOBILE_LIBRARY); \
	else \
		echo ""; \
		echo "Either no FIRETWEET_MAIN_DIR variable was passed or the given value is not a";\
		echo "directory. You'll have to copy the $(LANTERN_MOBILE_LIBRARY) file manually:"; \
		echo ""; \
		echo "cp -v $(LANTERN_MOBILE_DIR)/$(LANTERN_MOBILE_LIBRARY) \$$FIRETWEET_MAIN_DIR"; \
	fi

android-lib-dist: genconfig android-lib

clean:
	@rm -f lantern_linux* && \
	rm -f lantern_darwin* && \
	rm -f lantern_windows* && \
	rm -f lantern-installer* && \
	rm -f update_* && \
	rm -f *.deb && \
	rm -f *.png && \
	rm -rf *.app && \
	git checkout ./src/github.com/getlantern/flashlight/ui/resources.go && \
	rm -f src/github.com/getlantern/flashlight/*.syso && \
	rm -f *.dmg && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/bin && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/bindings/go_bindings && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/gen && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/libs && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/res && \
	rm -rf $(LANTERN_MOBILE_DIR)/libflashlight/src && \
	rm -rf $(LANTERN_MOBILE_DIR)/app
