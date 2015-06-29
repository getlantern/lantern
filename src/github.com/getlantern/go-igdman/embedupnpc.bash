#!/bin/bash

###############################################################################
#
# This script regenerates the source files that embed the upnpc executable.
#
###############################################################################

function die() {
  echo $*
  exit 1
}

if [ -z "$BNS_CERT" ] || [ -z "$BNS_CERT_PASS" ]
then
	die "$0: Please set BNS_CERT and BNS_CERT_PASS to the bns_cert.p12 signing key and the password for that key"
fi

osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in binaries/windows/upnpc-unsigned -out binaries/windows/upnpc || die "Could not sign upnpc on windows"
# osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in binaries/windows/natty -out binaries/windows/natty || die "Could not sign natty windows"
codesign -s "Developer ID Application: Brave New Software Project, Inc" -f binaries/osx/upnpc || die "Could not sign upnpc on macintosh"

go-bindata -nomemcopy -nocompress -pkg igdman -prefix binaries/osx -o igdman/upnpc_darwin.go binaries/osx
go-bindata -nomemcopy -pkg igdman -prefix binaries/windows -o igdman/upnpc_windows.go binaries/windows
# go-bindata -nomemcopy -nocompress -pkg bin -prefix binaries/linux_386 -o natty/bin/linux_386.go binaries/linux_386
# go-bindata -nomemcopy -nocompress -pkg bin -prefix binaries/linux_amd64 -o natty/bin/linux_amd64.go binaries/linux_amd64
# go-bindata -nomemcopy -nocompress -pkg bin -prefix binaries/windows -o natty/bin/windows.go binaries/windows
