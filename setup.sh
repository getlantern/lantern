#!/usr/bin/env bash

# get the OS using uname
if [[ "$(uname)" == "Darwin" ]]; then
	echo "unsupported OS: MacOS"
	exit 1
elif [[ "$(uname -s)" == Linux* ]]; then
	echo "supported: Linux"

	if ! sudo apt-get update -y; then
		echo "failed update"
		exit 1
	fi

	if ! sudo apt-get upgrade -y; then
		echo "failed upgrade"
		exit 1
	fi
	
	if ! sudo apt install -y pkg-config; then
		echo "failed pkg-config install"
		exit 1
	fi

	if ! sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa; then
		echo "failed tools install"
		exit 1
	fi

	if ! sudo apt install -y libgtk-3-dev; then
		echo "failed gtk install"
		exit 1
	fi

	if ! sudo apt install -y libwebkit2gtk-4.1-dev; then
		echo "failed webkit install"
		exit 1
	fi

	if ! sudo apt install libcurl4-openssl-dev; then
		echo "failed curl install"
		exit 1
	fi

    if dpkg -l | grep -q libappindicator3-1; then
        sudo apt remove --purge -y libappindicator3-1
    fi

    if ! sudo apt install -y libayatana-appindicator3-dev; then
        echo "failed ayatana-appindicator3 install"
        exit 1
    fi

	if ! sudo apt install -y openjdk-11-jdk; then
		echo "failed jdk install"
		exit 1
	fi

	if ! sudo apt-get install -y libc6:amd64 libstdc++6:amd64 lib32z1 libbz2-1.0:amd64; then
		echo "failed android deps"
		exit 1
	fi

	if ! sudo apt install -y ninja-build; then
		echo "failed ninja install"
		exit 1
	fi
	if ! sudo apt install -y build-essential; then
		echo "failed build-essential install"
		exit 1
	fi

	if ! sudo apt install -y cmake; then
		echo "failed cmake install"
		exit 1
	fi

	if ! which flutter; then
		install_flutter
	else
		echo "flutter already installed"
	fi

	if ! flutter pub outdated; then
		echo "flutter pub outdated failed"
		exit 1
	fi

	if ! flutter pub upgrade; then
		echo "flutter pub upgrade failed"
		exit 1
	fi

else
	echo "unsupported OS: unknown" 
	exit 1
fi


install_flutter() {
	if ! flutter doctor -v; then
		echo "flutter doctor failed"
		exit 1
	fi
}
