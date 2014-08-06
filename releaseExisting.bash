#!/usr/bin/env bash

# This script moves existing installers to be the "newest" release installers
# users will actually install using the installer wrappers.

# Amazon credentials are defined in ~/.boto
function die() {
  echo $*
  exit 1
}

if [ $# -ne "2" ]
then
    die "$0: Received $# args, expected base name and gneeric installer base name, as in 'lantern-1.0.0-beta7-789a299 lantern-installer'"
fi

baseName=$1
bucket="lantern"
names=($baseName.exe $baseName.dmg $baseName-32-bit.deb $baseName-64-bit.deb)
tag=${baseName:0:${#baseName}-8}
#names=($baseName-32-bit.deb $baseName-64-bit.deb)
newest=$2

for name in "${names[@]}"
do
  echo "$name"
  if [ "$name" == "$baseName.exe" ]; then
    echo "Setting newest"
    ext=".exe"
  elif [ "$name" == "$baseName.dmg" ]; then
    ext=".dmg"
  elif [ "$name" == "$baseName-32-bit.deb" ]; then
    ext="-32.deb"
  elif [ "$name" == "$baseName-64-bit.deb" ]; then
    ext="-64.deb"
  fi

  newestName=$newest$ext
  echo "Latest name: $newestName"

  fullurl=https://s3.amazonaws.com/lantern/$name
  echo "Downloading existing file from $fullurl"
  
  test -f $name || curl -O https://s3.amazonaws.com/lantern/$name

  test -f $name || die "File still does not exist at $name?"

  echo "Copying on S3 to newest file"
  ./copys3file.py $name $newestName || die "Could not copy s3 file to newest!"

  #echo "Uploading binary $name to tag 'latest'"
  #./uploadghasset.rb latest $name

  #echo "Uploading binary $name to tag '$tag'"
  #./uploadghasset.rb $tag $name

  # TODO: DO ALL THIS IN THE PYTHON SCRIPT
  shasum $name | cut -d " " -f 1 > $newestName.sha1
  echo "Uploading SHA-1 `cat $newestName.sha1`"
  aws -putp $bucket $newestName.sha1
done


