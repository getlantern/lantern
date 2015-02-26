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

extended_description="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed nibh erat, consequat eget varius et, posuere sit amet odio. Ut sit amet purus vel tortor gravida cursus nec et dui. In tristique mattis fringilla. Fusce semper, turpis vitae tempus scelerisque, felis dolor viverra urna, eget tempor lacus ante ut quam. Curabitur non porttitor metus. Duis pretium lorem vitae accumsan scelerisque. Duis in tellus id odio placerat laoreet. Phasellus efficitur lacinia blandit.\n Vivamus euismod odio eu tempor ultrices. Duis facilisis volutpat semper. Aliquam et est eget orci tristique congue. Vestibulum convallis erat vitae eros condimentum, a posuere risus blandit. Cras sed eros id metus luctus aliquam. Curabitur ullamcorper lacus eget scelerisque tincidunt. Vestibulum eleifend tristique augue in luctus. Integer malesuada, enim a bibendum dictum, justo dui fermentum tellus, vel tincidunt nibh dui condimentum lectus. Donec non metus ac sem luctus pulvinar. Cras nibh nisl, vulputate vitae purus quis, placerat pretium magna. In sodales, tellus at dapibus fringilla, est urna imperdiet orci, ac luctus urna lorem sed sapien. Aenean cursus purus nec turpis eleifend porttitor. Nulla quis luctus eros.\n Aenean dapibus odio ac lacinia molestie. Fusce facilisis, velit eget egestas convallis, sem risus dignissim tortor, et porta leo neque a nulla. Curabitur ultricies vel ligula quis interdum. Fusce elementum posuere odio, quis eleifend lectus porta non. Aliquam mattis tortor quis euismod fermentum. Suspendisse sit amet orci a nibh tempor ullamcorper. Curabitur nec nulla massa. Fusce nec dolor ac tellus efficitur imperdiet at nec purus. Donec viverra congue condimentum. Nullam fringilla dignissim erat, vel blandit ante elementum quis."

fpm -s dir -t deb -n lantern -v $version -m "Lantern Team <team@getlantern.org>" --description "An app to end censorship\n$extended_description" --category net --license "Apache 2.0" --vendor "Brave New Software" --url https://www.getlantern.org --deb-compression xz -f -C $workdir usr || die "Couldn't create .deb package"


