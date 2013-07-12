#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}
perl -pi -e "s/org.lantern.Launcher/org.lantern.Diagnostics" || die "Could not swap main class?"
cp src/test/resources/cacerts install/common/ || die "Could not copy cacerts?"
cp src/test/resources/test.properties install/common/ || die "Could not copy test.properties"

./winInstall.bash HEAD false || die "Could not build diagnostic tool?"
