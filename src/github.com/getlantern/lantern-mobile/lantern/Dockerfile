# Dockerfile to build an image able to compile flashlight for iOS and Android
#
# > make docker

FROM fedora:22
MAINTAINER "Ulysses Aalto" <uaalto@getlantern.org>

ENV GO_VERSION go1.5.3
ENV GOROOT_BOOTSTRAP /go1.5.3
ENV GOROOT /go
ENV GOPATH /

ENV PATH $PATH:$GOROOT/bin
ENV WORKDIR /lantern

# Updating system.
RUN dnf -y update && dnf clean all

# Requisites for building Go.
RUN dnf install -y git tar patch gzip curl hostname pcre-devel && dnf clean all

# Compilers and tools for CGO.
RUN dnf install -y gcc gcc-c++ libgcc.i686 gcc-c++.i686 glibc-static pkgconfig && dnf clean all

# Requisites for bootstrapping.
RUN dnf install -y glibc-devel glibc-static && dnf clean all
RUN dnf install -y glibc-devel.i686 glib2-static.i686 glibc.i686 && dnf clean all

# Debugging
RUN dnf install -y make vim strace tmux && dnf clean all

# Install Go.
#   1) 1.5 for bootstrap.
ENV GOROOT_BOOTSTRAP /go1.5.3
RUN (curl -sSL https://golang.org/dl/go1.5.3.linux-amd64.tar.gz | tar -vxz -C /tmp) && \
	mv /tmp/go $GOROOT_BOOTSTRAP

#   2) Download and cross compile the Go on revision GOREV.
#
# GOVERSION string is the output of 'git log -n 1 --format="format: devel +%h %cd" HEAD'
# like in go tool dist.
ENV GO_REV go1.5.3
#ENV GO_VERSION go1.5.1

ENV GOROOT /go
ENV PATH $GOROOT/bin:$PATH

RUN mkdir -p $GOROOT && \
    curl -sSL "https://go.googlesource.com/go/+archive/$GO_REV.tar.gz" | tar -vxz -C $GOROOT
RUN echo $GO_VERSION > $GOROOT/VERSION
RUN cd $GOROOT/src && ./all.bash

# Install Android SDK
RUN dnf install -y java-1.8.0-openjdk-devel.x86_64
RUN curl -L http://dl.google.com/android/android-sdk_r22-linux.tgz | tar xz -C /usr/local
ENV ANDROID_HOME /usr/local/android-sdk-linux
# Install Android tools
RUN echo y | /usr/local/android-sdk-linux/tools/android update sdk --no-ui --all --filter platform-tools,build-tools-21.1.2,android-22,extra-android-support

# Install and initialize gomobile
RUN go get -v golang.org/x/mobile/cmd/gomobile
RUN gomobile init -v

RUN dnf install -y zip unzip && dnf clean all

RUN mkdir -p $WORKDIR

VOLUME [ "$WORKDIR" ]

WORKDIR $WORKDIR
