###############################################################################
#
# This script regenerates the source files that embed the pac-cmd executable.
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

BINPATH=../pac-cmd/binaries

mv $BINPATH/windows/pac.exe $BINPATH/windows/pac
osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $BINPATH/windows/pac -out $BINPATH/windows/pac || die "Could not sign windows"
go-bindata -nomemcopy -nocompress -pkg pac -prefix $BINPATH/windows -o pac_bytes_windows.go $BINPATH/windows
mv $BINPATH/windows/pac $BINPATH/windows/pac.exe

go-bindata -nomemcopy -nocompress -pkg pac -prefix $BINPATH/linux_386 -o pac_bytes_linux_386.go $BINPATH/linux_386
go-bindata -nomemcopy -nocompress -pkg pac -prefix $BINPATH/linux_amd64 -o pac_bytes_linux_amd64.go $BINPATH/linux_amd64
#go-bindata -nomemcopy -nocompress -pkg pac -prefix $BINPATH/linux_arm -o pac_bytes_linux_arm.go $BINPATH/linux_arm

codesign -s "Developer ID Application: Brave New Software Project, Inc" -f $BINPATH/darwin/pac || die "Could not sign macintosh"
go-bindata -nomemcopy -nocompress -pkg pac -prefix $BINPATH/darwin -o pac_bytes_darwin.go $BINPATH/darwin
