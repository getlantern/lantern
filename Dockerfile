# This docker machine is able to compile and sign Lantern for Linux and
# Windows.

FROM fedora:21
MAINTAINER "The Lantern Team" <team@getlantern.org>

ENV WORKDIR /lantern
ENV SECRETS /secrets

RUN mkdir -p $WORKDIR
RUN mkdir -p $SECRETS

# Updating system.
RUN yum install -y deltarpm && yum update -y && yum clean packages

# Requisites for building Go.
RUN yum install -y git tar gzip curl hostname && yum clean packages

# Compilers and tools for CGO.
RUN yum install -y gcc gcc-c++ libgcc.i686 gcc-c++.i686 pkg-config && yum clean packages

# Requisites for bootstrapping.
RUN yum install -y glibc-devel glibc-static && yum clean packages
RUN yum install -y glibc-devel.i686 glib2-static.i686 glibc-2.20-8.fc21.i686 libgcc.i686 && yum clean packages

# Requisites for ARM
# ARM EABI toolchain must be grabbed from an contributor repository, such as:
# https://copr.fedoraproject.org/coprs/lantw44/arm-linux-gnueabi-toolchain/
RUN yum install -y yum-utils && \
  rpm --import https://copr-be.cloud.fedoraproject.org/results/lantw44/arm-linux-gnueabi-toolchain/pubkey.gpg && \
  yum-config-manager --add-repo=https://copr.fedoraproject.org/coprs/lantw44/arm-linux-gnueabi-toolchain/repo/fedora-21/lantw44-arm-linux-gnueabi-toolchain-fedora-21.repo && \
  yum install -y arm-linux-gnueabi-gcc arm-linux-gnueabi-binutils arm-linux-gnueabi-glibc && \
  yum clean packages

# Requisites for windows.
RUN yum install -y mingw32-gcc.x86_64 && yum clean packages

# Requisites for building Lantern on Linux.
RUN yum install -y gtk3-devel libappindicator-gtk3 libappindicator-gtk3-devel && yum clean packages
RUN yum install -y pango.i686 pango-devel.i686 gtk3-devel.i686 gdk-pixbuf2-devel.i686 cairo-gobject-devel.i686 \
  atk-devel.i686 libappindicator-gtk3-devel.i686 libdbusmenu-devel.i686 dbus-devel.i686 pkgconfig.i686 && \
  yum clean packages

# Requisites for packing Lantern for Debian.
# The fpm packer. (https://rubygems.org/gems/fpm)
RUN yum install -y ruby ruby-devel make && yum clean packages
RUN gem install fpm

# Requisites for packing Lantern for Windows.
RUN yum install -y osslsigncode mingw32-nsis && yum clean packages

# Required for compressing update files
RUN yum install -y bzip2 && yum clean packages

# Requisites for genassets.
RUN curl --silent --location https://rpm.nodesource.com/setup_5.x | bash -
RUN yum -y install nodejs && yum clean packages
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
