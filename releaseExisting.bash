#!/usr/bin/env bash

# This script moves existing installers to be the "newest" release installers
# users will actually install using the installer wrappers.
function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
    die "$0: Received $# args, expected base name such as lantern-1.0.0-beta7-789a299"
fi

baseName=$1
bucket="lantern"
names=($baseName.exe $baseName.dmg $baseName-32-bit.deb $baseName-64-bit.deb)
#names=($baseName-32-bit.deb $baseName-64-bit.deb)

for name in "${names[@]}"
do
  echo "$name"
  if [ "$name" == "$baseName.exe" ]; then
    echo "Setting newest"
    newestName="newest.exe"
  elif [ "$name" == "$baseName.dmg" ]; then
    newestName="newest.dmg"
  elif [ "$name" == "$baseName-32-bit.deb" ]; then
    newestName="newest-32.deb"
  elif [ "$name" == "$baseName-64-bit.deb" ]; then
    newestName="newest-64.deb"
  fi
  echo "Latest name: $newestName"

  echo "Downloading existing file..."
  test -f $name || curl -O https://s3.amazonaws.com/lantern/$name

  echo "Copying on S3 to newest file"
  ./copys3file.py $name || die "Could not copy s3 file to newest!"

  shasum $name | cut -d " " -f 1 > $newestName.sha1
  echo "Uploading SHA-1 `cat $newestName.sha1`"
  aws -putp $bucket $newestName.sha1
done


