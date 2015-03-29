SHELL := /bin/bash

DOCKER := $(shell which docker 2> /dev/null);
GO := $(shell which go 2> /dev/null);

BUILD_DATE := $(shell date -u +%Y%m%d.%H%M%S);
GIT_REVISION := $(shell git describe --abbrev=0 --tags --exact-match || git rev-parse --short HEAD);
LOGGLY_TOKEN := 469973d5-6eaf-445a-be71-cf27141316a1;
LDFLAGS := -w -X main.version $(GIT_REVISION) -X main.buildDate $(BUILD_DATE) -X github.com/getlantern/flashlight/logging.logglyToken \"$(LOGGLY_TOKEN)\"

system-checks:
	if [[ "$(DOCKER)" == "" ]]; then echo 'Missing "docker" command.'; exit 1; fi;
	if [[ "$(GO)" == "" ]]; then echo 'Missing "go" command.'; exit 1; fi;

# This is to be called within the docker image.
docker-genassets:
	source setenv.bash && \
	echo "Generating UI resources for embedding..." && \
	\
	LANTERN_UI="src/github.com/getlantern/lantern-ui" && \
	APP="$$LANTERN_UI/app" && \
	DIST="$$LANTERN_UI/dist" && \
	DEST="src/github.com/getlantern/flashlight/ui/resources.go" && \
	\
	if [ "$$UPDATE_DIST" ]; then \
			echo "Updating dist folder" && \
			cd $$LANTERN_UI && \
			npm install && \
			rm -Rf dist && \
			gulp build && \
			cd -; \
	else \
			echo "Not updating dist folder."; \
	fi && \
	\
	echo "Generating resources.go." && \
	go install github.com/getlantern/tarfs/tarfs && \
	echo "// +build prod" > $$DEST && \
	echo " " >> $$DEST && \
	tarfs -pkg ui $$DIST >> $$DEST && \
	echo "Now embedding lantern.ico to windows executable" && \
	go install github.com/akavel/rsrc && \
	rsrc -ico lantern.ico -o src/github.com/getlantern/flashlight/lantern.syso;

docker: system-checks

linux: docker-genassets linux-386 linux-amd64

windows: docker-genassets windows-386

darwin: docker-genassets darwin-386

linux-amd64:
	source setenv.bash && \
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o lantern_linux_amd64 -tags="prod" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

linux-386:
	source setenv.bash && \
	CGO_ENABLED=1 GOOS=linux GOARCH=386 go build -o lantern_linux_386 -tags="prod" -ldflags="$(LDFLAGS) -linkmode internal -extldflags \"-static\"" github.com/getlantern/flashlight

windows-386:
	source setenv.bash && \
	CGO_ENABLED=1 GOOS=windows GOARCH=386 go build -o lantern_windows_386.exe -tags="prod" -ldflags="$(LDFLAGS) -H=windowsgui" github.com/getlantern/flashlight;

darwin-amd64:
	source setenv.bash && \
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build -o lantern_darwin_amd64 -tags="prod" -ldflags="$(LDFLAGS)" github.com/getlantern/flashlight;

package-linux: linux

package-windows: windows

package-darwin: darwin

all: docker linux-386 linux-amd64 windows-386 darwin-amd64

clean:
	rm -f lantern_darwin_*
	rm -f lantern_linux_*
	rm -f lantern_windows_*

.PHONY: clean all
