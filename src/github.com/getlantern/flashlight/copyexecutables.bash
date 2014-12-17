#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Path to lantern required"
fi

if [ ! -z "$BNS_CERT" ]
then
	if [ -z "$BNS_CERT_PASS" ]
	then
		die "$0: Please set BNS_CERT_PASS to the password for the $BNS_CERT signing key"
	fi
fi

# Sign while we're at it...

lantern=$1/install
codesign -s "Developer ID Application: Brave New Software Project, Inc" -f flashlight_darwin_amd64 || die "Could not code sign?"

echo "Copying executables to $1"

cp flashlight_darwin_amd64 $lantern/osx/pt/flashlight/flashlight || die "Could not copy darwin"
if [ -z "$BNS_CERT" ]
then
	echo "WARNING - No BNS_CERT set, simply copying windows executable"
	cp flashlight_windows_386.exe $lantern/win/pt/flashlight/flashlight.exe || die "Could not copy windows"
else
	echo "Signing windows executable"
	osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in flashlight_windows_386.exe -out $lantern/win/pt/flashlight/flashlight.exe || die "Could not sign windows"
fi
cp flashlight_linux_386 $lantern/linux_x86_32/pt/flashlight/flashlight || die "Could not copy linux 32"
cp flashlight_linux_amd64 $lantern/linux_x86_64/pt/flashlight/flashlight || die "Could not copy linux 64"
