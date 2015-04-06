# Dockerfile to build an image able to compile flashlight for a variety of
# platforms.
#
# > make docker

FROM fedora:21
MAINTAINER "José Carlos Nieto" <xiam@getlantern.org>

ENV GO_VERSION go1.4.2
ENV GOROOT_BOOTSTRAP /go1.4
ENV GOROOT /go
ENV GOPATH /

ENV PATH $PATH:$GOROOT/bin
ENV WORKDIR /flashlight-build

# Go binary for bootstrapping.
ENV GO_PACKAGE_URL https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz

# Updating system.
RUN yum -y update && yum clean all

# Requisites for building Go.
RUN yum install -y git tar gzip curl hostname pcre-devel mercurial && yum clean all

# Compilers and tools for CGO.
RUN yum install -y gcc gcc-c++ libgcc.i686 gcc-c++.i686 pkg-config && yum clean all

# Getting Go.
RUN (curl -sSL $GO_PACKAGE_URL | tar -xvz -C /tmp) && \
  mv /tmp/go $GOROOT_BOOTSTRAP

# Getting Go source.
RUN mkdir -p $GOROOT && \
  git clone https://go.googlesource.com/go $GOROOT && \
  cd $GOROOT && \
  git checkout -b go1.4 origin/release-branch.go1.4

# Bootstrapping Go.
RUN cd $GOROOT/src && CGO_ENABLED=1 ./all.bash

# Requisites for bootstrapping.
RUN yum install -y glibc-devel glibc-static && yum clean all
RUN yum install -y glibc-devel.i686 glib2-static.i686 glibc-2.20-8.fc21.i686 libgcc.i686 && yum clean all

# Requisites for windows.
RUN yum install -y mingw32-gcc.x86_64 && yum clean all

# Boostrapping Go for different platforms.
RUN cd $GOROOT/src && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 ./make.bash --no-clean
RUN cd $GOROOT/src && CGO_ENABLED=1 GOOS=linux GOARCH=386 ./make.bash --no-clean
RUN cd $GOROOT/src && CXX_FOR_TARGET=i686-w64-mingw32-g++ CC_FOR_TARGET=i686-w64-mingw32-gcc CGO_ENABLED=1 GOOS=windows GOARCH=386 ./make.bash --no-clean

RUN cd $GOROOT/src && GOARCH=386 ./make.bash --no-clean

# Requisites for building Lantern on Linux.
RUN yum install -y gtk3-devel libappindicator-gtk3 libappindicator-gtk3-devel && yum clean all
RUN yum install -y pango.i686 pango-devel.i686 gtk3-devel.i686 gdk-pixbuf2-devel.i686 cairo-gobject-devel.i686 atk-devel.i686 libappindicator-gtk3-devel.i686 libdbusmenu-devel.i686 dbus-devel.i686 pkgconfig.i686 && yum clean all

# Requisites for packing Lantern for Debian.
# The fpm packer. (https://rubygems.org/gems/fpm)
RUN yum install -y ruby ruby-devel make && yum clean all
RUN gem install fpm

# Requisites for packing Lantern for Windows.
RUN yum install -y osslsigncode mingw32-nsis && yum clean all

# Requisites for genassets.
RUN yum install -y nodejs npm && yum clean all
RUN npm install -g gulp

# Expect the $WORKDIR volume to be mounted.
ENV SECRETS /secrets

RUN mkdir -p $WORKDIR
RUN mkdir -p $SECRETS

VOLUME [ "$WORKDIR" ]

WORKDIR $WORKDIR
