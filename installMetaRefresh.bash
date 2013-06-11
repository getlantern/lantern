#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "4" ]
then
    die "$0: Received $# args... dir, name, name of latest file (latest.dmg), and whether this is a release version required"
fi
dir=$1
name=$2
latestName=$3
release=$4

echo "Release version: $release"


if $release ; then
  bucket=lantern
  url=https//s3.amazonaws.com/$bucket/$name
  echo "Uploading to http://cdn.getlantern.org/$name..."
  aws -putp $bucket $name
  echo "Uploaded lantern to http://cdn.getlantern.org/$name"
  echo "Also available at $url"

  echo "RELEASING!!!!!"
#  pushd install/$dir || die "Could not change directories"
#  perl -pi -e "s;url_token;$url;g" $latestName || die "Could not replace URL token"

  # Makes sure it actually was replaced
#  grep $url $latestName || die "Something went wrong with creating latest dummy file"

  # Here's the trick -- send a custom mime type that's html instead of the mime type for the file extension
#  aws -putpm $bucket $latestName text/html || die "Could not upload latest?"

#  git checkout $latestName || die "Could not checkout"
#  popd

  echo "Copying on S3 to latest file"
  ./copys3file.py $name

  shasum $name | cut -d " " -f 1 > $latestName.sha1

  echo "Uploading SHA-1 `cat $latestName.sha1`"
  aws -putp $bucket $latestName.sha1
else
  echo "NOT RELEASING!!!"
fi

echo "INSTALLER AVAILABLE AT `pwd`/$name"
