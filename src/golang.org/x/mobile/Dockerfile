# Dockerfile to build an image with the local version of golang.org/x/mobile.
#
#  > docker build -t mobile $GOPATH/src/golang.org/x/mobile
#  > docker run -it --rm -v $GOPATH/src:/src mobile

FROM ubuntu:12.04

# Install system-level dependencies.
ENV DEBIAN_FRONTEND noninteractive
RUN echo "debconf shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections && \
	echo "debconf shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
RUN apt-get update && \
	apt-get -y install build-essential python-software-properties bzip2 unzip curl \
		git subversion mercurial bzr \
		libncurses5:i386 libstdc++6:i386 zlib1g:i386 && \
	add-apt-repository ppa:webupd8team/java && \
	apt-get update && \
	apt-get -y install oracle-java6-installer

# Install Ant.
RUN curl -L http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.2-bin.tar.gz | tar xz -C /usr/local
ENV ANT_HOME /usr/local/apache-ant-1.9.2

# Install Android SDK.
RUN curl -L http://dl.google.com/android/android-sdk_r23.0.2-linux.tgz | tar xz -C /usr/local
ENV ANDROID_HOME /usr/local/android-sdk-linux
RUN echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter build-tools-19.1.0 && \
	echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter platform-tools && \
	echo y | $ANDROID_HOME/tools/android update sdk --no-ui --all --filter android-19

# Install Android NDK.
RUN curl -L http://dl.google.com/android/ndk/android-ndk-r9d-linux-x86_64.tar.bz2 | tar xj -C /usr/local
ENV NDK_ROOT /usr/local/android-ndk-r9d
RUN $NDK_ROOT/build/tools/make-standalone-toolchain.sh --platform=android-9 --install-dir=$NDK_ROOT --system=linux-x86_64

# Install Gradle 2.1
# : android-gradle compatibility
#   http://tools.android.com/tech-docs/new-build-system/version-compatibility
RUN curl -L http://services.gradle.org/distributions/gradle-2.1-all.zip -o /tmp/gradle-2.1-all.zip && unzip /tmp/gradle-2.1-all.zip -d /usr/local && rm /tmp/gradle-2.1-all.zip
ENV GRADLE_HOME /usr/local/gradle-2.1

# Update PATH for the above.
ENV PATH $PATH:$ANDROID_HOME/tools
ENV PATH $PATH:$ANDROID_HOME/platform-tools
ENV PATH $PATH:$NDK_ROOT
ENV PATH $PATH:$ANT_HOME/bin
ENV PATH $PATH:$GRADLE_HOME/bin

# Install Go.
#   1) 1.4 for bootstrap.
ENV GOROOT_BOOTSTRAP /go1.4
RUN (curl -sSL https://golang.org/dl/go1.4.linux-amd64.tar.gz | tar -vxz -C /tmp) && \
	mv /tmp/go $GOROOT_BOOTSTRAP


#   2) Download and cross compile the Go on revision GOREV.
#
# GOVERSION string is the output of 'git log -n 1 --format="format: devel +%h %cd" HEAD'
# like in go tool dist.
# Revision picked on Jan 21, 2015.
ENV GO_REV      34bc85f6f3b02ebcd490b40f4d32907ff2e69af3
ENV GO_VERSION  devel +34bc85f Wed Jan 21 21:30:46 2015 +0000

ENV GOROOT /go
ENV GOPATH /
ENV PATH $PATH:$GOROOT/bin

RUN mkdir -p $GOROOT && \
	curl -sSL "https://go.googlesource.com/go/+archive/$GO_REV.tar.gz" | tar -vxz -C $GOROOT && \
	echo $GO_VERSION > $GOROOT/VERSION && \
	cd $GOROOT/src && \
	./all.bash && \
	CC_FOR_TARGET=$NDK_ROOT/bin/arm-linux-androideabi-gcc GOOS=android GOARCH=arm GOARM=7 ./make.bash

# Expect the GOPATH/src volume to be mounted.  (-v $GOPATH/src:/src)
VOLUME ["/src"]

# Generate a debug keystore to avoid it being generated on each `docker run`
# and fail `adb install -r <apk>` with a conflicting certificate error.
RUN keytool -genkeypair -alias androiddebugkey -keypass android -keystore ~/.android/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 365

WORKDIR $GOPATH/src/golang.org/x/mobile
