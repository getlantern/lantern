#!/bin/bash

echo "Generating UI resources for embedding"

LANTERN_UI="src/github.com/getlantern/lantern-ui"
APP="$LANTERN_UI/app"
DIST="$LANTERN_UI/dist"

if [ "$UPDATE_DIST" ]; then
    which gulp > /dev/null
    if [ $? -ne 0 ]
    then
        echo "Installing gulp tool (requires nodejs)"
        npm install -g gulp || die "Could not install gulp"
    fi
    
    echo "Updating dist folder"
    cd $LANTERN_UI
    npm install
    rm -Rf dist
    gulp build
    cd -
else
    echo "Not updating dist folder"
fi

echo "Generating resources.go"
go install github.com/getlantern/tarfs/tarfs
dest="src/github.com/getlantern/flashlight/ui/resources.go"
echo "// +build prod" > $dest
echo " " >> $dest
tarfs -pkg ui $DIST >> $dest 

echo "Now embedding lantern.ico to windows executable"
go install github.com/akavel/rsrc
rsrc -ico lantern.ico -o src/github.com/getlantern/flashlight/lantern.syso
