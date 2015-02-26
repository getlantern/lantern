#!/bin/bash

function die() {
  echo $*
  exit 1
}

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

workdir=$(mktemp -dt "$(basename $0).XXXXXXXXXX")

mkdir -p $workdir/usr/bin
mkdir -p $workdir/usr/share/applications
mkdir -p $workdir/usr/share/icons/hicolor/128x128/apps
mkdir -p $workdir/usr/share/doc/lantern

chmod -R 755 $workdir

cp deb-copyright $workdir/usr/share/doc/lantern/copyright
cp $binary $workdir/usr/bin/lantern
cp lantern.desktop $workdir/usr/share/applications
cp icon128x128on.png $workdir/usr/share/icons/hicolor/128x128/apps/lantern.png

which fpm > /dev/null
if [ $? -ne 0 ]
then
    echo "Installing fpm"
    sudo apt-get install ruby-dev build-essential
    sudo gem install fpm
fi

extended_description="Lantern allows you to access sites blocked by internet censorship.\nWhen you run it, Lantern reroutes traffic to selected domains through servers located where such domains aren't censored."

fpm -s dir -t deb -n lantern -v $version -m "Lantern Team <team@getlantern.org>" --description "Censorship circumvention tool\n$extended_description" --category net --license "Apache-2.0" --vendor "Brave New Software" --url https://www.getlantern.org --deb-compression xz -f -C $workdir usr || die "Couldn't create .deb package"


