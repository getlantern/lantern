#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}
echo "Swapping main class"
perl -pi -e "s/org.lantern.Launcher/org.lantern.Diagnostics/g" pom.xml || die "Could not swap main class?"

echo "Copying cacerts"
cp src/test/resources/cacerts install/common/ || die "Could not copy cacerts?"

echo "Copying test.properties"
cp src/test/resources/test.properties install/common/ || die "Could not copy test.properties"

echo "Running installer build process..."
./winInstall.bash HEAD false || die "Could not build diagnostic tool?"

echo "Cleaning up..."
rm install/common/cacerts
rm install/common/test.properties
git checkout pom.xml
