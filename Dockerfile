# This docker machine is able to compile and sign Lantern for Linux and
# Windows.

FROM fedora:22
MAINTAINER "The Lantern Team" <team@getlantern.org>

ENV WORKDIR /lantern
ENV SECRETS /secrets

RUN mkdir -p $WORKDIR
RUN mkdir -p $SECRETS

# Updating system.
RUN dnf install -y deltarpm && dnf update -y && dnf clean packages

# Requisites for building Go.
RUN dnf install -y git tar gzip curl hostname && dnf clean packages

# Compilers and tools for CGO.
RUN dnf install -y gcc gcc-c++ libgcc.i686 gcc-c++.i686 && dnf clean packages

# Requisites for bootstrapping.
RUN dnf install -y glibc-devel glibc-static && dnf clean packages
RUN dnf install -y glibc-devel.i686 glib2-static.i686 glibc.i686 libgcc.i686 && dnf clean packages

# Requisites for ARM
# ARM EABI toolchain must be grabbed from an contributor repository, such as:
# https://copr.fedoraproject.org/coprs/lantw44/arm-linux-gnueabi-toolchain/
RUN dnf install -y 'dnf-command(copr)' && \
  dnf copr enable -y lantw44/arm-linux-gnueabi-toolchain && \
  dnf install -y arm-linux-gnueabi-gcc arm-linux-gnueabi-binutils arm-linux-gnueabi-glibc && \
  dnf clean packages

# Requisites for windows.
RUN dnf install -y mingw32-gcc.x86_64 && dnf clean packages

# Requisites for building Lantern on Linux.
RUN dnf install -y gtk3-devel libappindicator-gtk3 libappindicator-gtk3-devel && dnf clean packages
RUN dnf install -y pango.i686 pango-devel.i686 gtk3-devel.i686 gdk-pixbuf2-devel.i686 cairo-gobject-devel.i686 \
  atk-devel.i686 libappindicator-gtk3-devel.i686 libdbusmenu-devel.i686 dbus-devel.i686 pkgconfig.i686 && \
  dnf clean packages

# Requisites for packing Lantern for Debian.
# The fpm packer. (https://rubygems.org/gems/fpm)
RUN dnf install -y ruby ruby-devel make && dnf clean packages
RUN gem install fpm

# Requisites for packing Lantern for Windows.
RUN dnf install -y osslsigncode mingw32-nsis && dnf clean packages

# Required for compressing update files
RUN dnf install -y bzip2 && dnf clean packages

# Requisites for genassets.
RUN curl --silent --location https://rpm.nodesource.com/setup_5.x | bash -
RUN dnf -y install nodejs && dnf clean packages
RUN npm install -g gulp

# Getting Go.
ENV GOROOT /usr/local/go
ENV GOPATH /

ENV PATH $PATH:$GOROOT/bin

ENV GO_PACKAGE_URL https://s3-eu-west-1.amazonaws.com/uaalto/go1.6.2_lantern_20160503_linux_amd64.tar.gz
RUN curl -sSL $GO_PACKAGE_URL | tar -xvzf - -C /usr/local

# Expect the $WORKDIR volume to be mounted.
VOLUME [ "$WORKDIR" ]

WORKDIR $WORKDIR
