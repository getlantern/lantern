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

mkdir -p $workdir/bin
mkdir -p $workdir/share/applications
mkdir -p $workdir/share/icons/hicolor/128x128/apps

cp $binary $workdir/bin/lantern
cp lantern.desktop $workdir/share/applications
cp icon128x128on.png $workdir/share/icons/hicolor/128x128/apps/lantern.png

which fpm > /dev/null
if [ $? -ne 0 ]
then
    echo "Installing fpm"
    sudo apt-get install ruby-dev build-essential
    sudo gem install fpm
fi

fpm -s dir -t deb -n lantern -v $version -m "Lantern Team <team@getlantern.org>"  --description "Censorship circumvention tool" --license "Apache 2.0" --vendor "Brave New Software" --url https://www.getlantern.org -f -C $workdir --prefix /usr bin share || die "Couldn't create .deb package"


