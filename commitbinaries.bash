#!/usr/bin/env bash

if [ $# -ne "2" ]
then
    die "$0: Received $# args... required: name and name of newest file (lantern-installer.dmg)"
fi
name=$1
newestName=$2

bindir=../lantern-binaries
echo "Copying binaries to $bindir" 
test -d $bindir || die "No $bindir repo to deploy binaries to?"
cp $newestName.sha1 $bindir/$name.sha1 || die "Could not copy $newestName.sha1 to $bindir/$name.sha1?"
cp $newestName.sha1 $bindir || die "Could not copy $newestName.sha1 to $bindir?"
#cp $name $bindir || die "Could not copy $name to $bindir?"
cp $name $bindir/$newestName || die "Could not copy $name to $bindir/$newestName?"

pushd $bindir || die "Could not move to binary repo?"
git add *
git commit -m "Latest binaries for $name" || die "Could not commit $name?"
  
echo "Uploading binary $newestName in lantern-binaries repo"
git push origin master || die "Could not push?" 
popd
