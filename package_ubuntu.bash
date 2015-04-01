#!/bin/bash

function die() {
  echo $*
  exit 1
}

INSTALLER_RESOURCES=./installer-resources/linux

if [ $# -lt "1" ]
then
    die "$0: Version required"
fi
version=$1

binary="lantern_linux"

if [ ! -f $binary ]
then
    die "Please compile lantern using ./linuxcompile.bash before running $0"
fi

# Preparing directory layout.
workdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")

mkdir -p $workdir/usr/bin
mkdir -p $workdir/usr/lib/lantern
mkdir -p $workdir/usr/share/applications
mkdir -p $workdir/usr/share/icons/hicolor/128x128/apps
mkdir -p $workdir/usr/share/doc/lantern

chmod -R 755 $workdir

# Copying resources.
cp $INSTALLER_RESOURCES/deb-copyright $workdir/usr/share/doc/lantern/copyright
cp $INSTALLER_RESOURCES/lantern.desktop $workdir/usr/share/applications
cp $INSTALLER_RESOURCES/icon128x128on.png $workdir/usr/share/icons/hicolor/128x128/apps/lantern.png

# Copying Lantern binary and Lantern wrapper.
cp $binary $workdir/usr/lib/lantern/lantern-binary
cp $INSTALLER_RESOURCES/lantern.sh $workdir/usr/lib/lantern/

# We are not going to execute Lantern without the wrapper.
chmod -x $workdir/usr/lib/lantern/lantern-binary
chmod +x $workdir/usr/lib/lantern/lantern.sh

# Leaving symlink in place.
ln -s /usr/lib/lantern/lantern.sh $workdir/usr/bin/lantern

# Creating .deb package.
which fpm > /dev/null
if [ $? -ne 0 ]
then
    echo "Installing fpm"
    sudo apt-get install ruby-dev build-essential
    sudo gem install fpm
fi

extended_description="Lantern allows you to access sites blocked by internet censorship.\nWhen you run it, Lantern reroutes traffic to selected domains through servers located where such domains aren't censored."

fpm -s dir -t deb -n lantern -v $version -m "Lantern Team <team@getlantern.org>" --description "Censorship circumvention tool\n$extended_description" --category net --license "Apache-2.0" --vendor "Brave New Software" --url https://www.getlantern.org --deb-compression xz -f -C $workdir usr || die "Couldn't create .deb package"
