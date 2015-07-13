# Dockerfile to build an image able to compile flashlight for iOS and Android
#
# > make docker

FROM fedora:21
MAINTAINER "Ulysses Aalto" <uaalto@getlantern.org>

ENV GO_VERSION go1.4.2
ENV GOROOT_BOOTSTRAP /go1.4
ENV GOROOT /go
ENV GOPATH /

ENV PATH $PATH:$GOROOT/bin
ENV WORKDIR /lantern

# Updating system.
RUN yum -y update && yum clean all

# Requisites for building Go.
RUN yum install -y git tar gzip curl hostname pcre-devel && yum clean all

# Compilers and tools for CGO.
RUN yum install -y gcc gcc-c++ libgcc.i686 gcc-c++.i686 glibc-static pkg-config && yum clean all

# Install Go.
#   1) 1.4 for bootstrap.
ENV GOROOT_BOOTSTRAP /go1.4
RUN (curl -sSL https://golang.org/dl/go1.4.linux-amd64.tar.gz | tar -vxz -C /tmp) && \
	mv /tmp/go $GOROOT_BOOTSTRAP

#   2) Download and cross compile the Go on revision GOREV.
#
# GOVERSION string is the output of 'git log -n 1 --format="format: devel +%h %cd" HEAD'
# like in go tool dist.
# Revision picked on Jul 13, 2015.
ENV GO_REV 242ec168c1394038cee17935f92e28fc24baac8e
ENV GO_VERSION devel +242ec16 Mon Jul 13 17:51:09 2015 +0000

ENV GOROOT /go
ENV GOPATH /
ENV PATH $PATH:$GOROOT/bin

RUN mkdir -p $GOROOT && \
    curl -sSL "https://go.googlesource.com/go/+archive/$GO_REV.tar.gz" | tar -vxz -C $GOROOT
RUN echo $GO_VERSION > $GOROOT/VERSION
RUN cd $GOROOT/src && ./all.bash

# Install Android SDK
RUN yum install -y java-1.8.0-openjdk-devel.x86_64
RUN curl -L http://dl.google.com/android/android-sdk_r23.0.2-linux.tgz | tar xz -C /usr/local
ENV ANDROID_HOME /usr/local/android-sdk-linux
RUN echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter build-tools-19.1.0 && \
	echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter platform-tools && \
	echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter android-19

# Install and initialize gomobile
RUN go get golang.org/x/mobile/cmd/gomobile
RUN gomobile init

RUN mkdir -p $WORKDIR

VOLUME [ "$WORKDIR" ]

WORKDIR $WORKDIR
