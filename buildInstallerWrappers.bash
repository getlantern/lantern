#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

test -f ./install/wrapper/InstallDownloader.class || die "Could not find InstallerDownloader class file?"
file ./install/wrapper/InstallDownloader.class | grep 51 && die "InstallerDownloader.class was compiled with java7"

install4jc -L $INSTALL4J_KEY || die "Could not update license information?"
install4jc -v --win-keystore-password=$INSTALL4J_WIN_PASS --mac-keystore-password=$INSTALL4J_MAC_PASS ./install/wrapper/wrapper.install4j || die "Could not build installer?"

cd install/win || die "Could not cd into install/win?"
mv ../lantern-net-installer_windows_0_0_1.exe ../lantern-net-installer-win-install4j.exe || die "Could not move old installer"
makensis lantern.nsi || die "Could not make nsis?"
./osslsigncode sign -pkcs12 ../../../secure/bns_cert.p12 -pass $INSTALL4J_WIN_PASS -in lantern-installer.exe -out ../lantern-net-installer_windows_0_0_1.exe || die "Could not sign executable"

