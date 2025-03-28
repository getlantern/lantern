FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

ENV GO_VERSION=1.23.1
ENV GO_URL=https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    unzip \
    clang \
    cmake \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter Linux dependencies
RUN apt-get update && apt-get install -y \
    ninja-build \
    clang \
    lld \
    libgtk-3-dev \
    libstdc++-12-dev \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Go
RUN curl -fsSL "$GO_URL" -o go.tar.gz \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz \
    && go version

# Install Flutter (latest stable)
RUN git clone https://github.com/flutter/flutter.git /opt/flutter \
&& /opt/flutter/bin/flutter --version

ENV PATH="/opt/flutter/bin:$PATH"

RUN git config --global --add safe.directory /opt/flutter

WORKDIR /app

COPY . .

RUN flutter channel master \
&& flutter upgrade \
# TODO: remove this version solving fix for intl
&& flutter update-packages --cherry-pick-package intl --cherry-pick-version 0.19.0 \
&& flutter pub get

RUN make linux

CMD ["/bin/bash"]