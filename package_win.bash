#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Version required"
fi
version=$1

binary="lantern_windows_386.exe"
out="lantern.exe"
# Below is defined in lantern.nsi
installer_unsigned="lantern-installer-unsigned.exe"
installer="lantern-installer.exe"

if [ ! -f $binary ]
then
    die "Please compile lantern using ./crosscompile.bash or ./tagandbuild.bash before running package_win.bash"
fi

if [ -z "$BNS_CERT" ]
then
    die "$0: Please set BNS_CERT to the bns signing certificate for windows"
fi

if [ -z "$BNS_CERT_PASS" ]
then
    die "$0: Please set BNS_CERT_PASS to the password for the $BNS_CERT signing key"
fi

which osslsigncode > /dev/null
if [ $? -ne 0 ]
then
    echo "Installing osslsigncode"
    brew install osslsigncode || die "Could not install osslsigncode"
fi
osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $binary -out $out || die "Could not sign windows executable"

which makensis > /dev/null
if [ $? -ne 0 ]
then
    echo "Installing makensis"
    brew install makensis || die "Could not install makensis"
fi
makensis -DVERSION=$version lantern.nsi || die "Unable to build installer"
osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $installer_unsigned -out $installer || die "Could not sign windows installer"

echo "Windows executable available at $out"
echo "Compressed executable archiveavailable at $installer"

