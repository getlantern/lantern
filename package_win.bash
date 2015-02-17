#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

binary="lantern_windows_386.exe"
out="lantern.exe"

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

osslsigncode sign -pkcs12 "$BNS_CERT" -pass "$BNS_CERT_PASS" -in $binary -out $out || die "Could not sign windows executable"

echo "Windows executable available at $out"

