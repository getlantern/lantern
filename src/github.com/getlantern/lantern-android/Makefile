# Requisites.
DOCKER_CLI 	:= $(shell which docker || (echo "ERR: The \"docker\" command line utility was not found in this system. See https://docs.docker.com/." && exit 1))
GO_CLI 			:= $(shell which go || (echo "ERR: The \"go\" command line utility was not found in this system. See https://golang.org/doc/install." && exit 1))

export DOCKER_CLI
export GO_CLI

all: docker-golang-mobile .task-golang-mobile
	mkdir -p app
	cd libflashlight && \
		mkdir -p bindings/go_bindings && \
		gobind -lang=go github.com/getlantern/lantern-android/libflashlight/bindings > bindings/go_bindings/go_bindings.go && \
		gobind -lang=java github.com/getlantern/lantern-android/libflashlight/bindings > bindings/Flashlight.java
	$$DOCKER_CLI run -v $$GOPATH/src:/src golang/mobile /bin/bash -c \ "cd /src/github.com/getlantern/lantern-android/libflashlight && ./make.bash"

# clean removes temporary files, since we're using docker it may require you to
# use "sudo make clean"
clean:
	rm -rf libflashlight/bin
	rm -rf libflashlight/bindings/go_bindings
	rm -rf libflashlight/gen
	rm -rf libflashlight/libs
	rm -rf libflashlight/res
	rm -rf libflashlight/src
	rm -f .task-*
	rm -rf app

# docker-golang-mobile checks for the golang/mobile docker image, if it does
# not exists, it gets the golang/mobile Dockerfile and builds it.
docker-golang-mobile:
	$$DOCKER_CLI images | grep golang/mobile || docker pull golang/mobile

# .task-golang-mobile gets package requisites for building x/mobile.
.task-golang-mobile:
	# Getting x/mobile package.
	$$GO_CLI get -d golang.org/x/mobile/example/...
	# Installing gobind.
	$$GO_CLI get golang.org/x/mobile/cmd/gobind
	touch .task-golang-mobile

