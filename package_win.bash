#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

binary="lantern_windows_386.exe"
out="lantern.exe"
# Below is defined in lantern.nsi
installer_unsigned="lantern-installer-unsigned.exe"
installer="lantern-installer.exe"

if [ ! -f $binary ]
then
    die "Please compile lantern using ./crosscompile.bash or ./tagandbuild.bash before running package_win.bash"
fi

if [ ! -z "$BNS_CERT" ]
then
    if [ -z "$BNS_CERT_PASS" ]
    then
        die "$0: Please set BNS_CERT_PASS to the password for the $BNS_CERT signing key"
    fi
fi

which osslsigncode || echo "Installing osslsigncode" && brew install osslsigncode || die "Could not install osslsigncode"
osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $binary -out $out || die "Could not sign windows executable"

which makensis || echo "Installing makensis" && brew install makensis || die "Could not install makensis"
makensis lantern.nsi
osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $installer_unsigned -out $installer || die "Could not sign windows installer"

echo "Windows executable available at $out"
echo "Compressed executable archiveavailable at $installer"

