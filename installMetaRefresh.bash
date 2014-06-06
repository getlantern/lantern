#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "4" ]
then
    die "$0: Received $# args... dir, name, name of newest file (newest.dmg), and whether this is a release version required"
fi
dir=$1
name=$2
newestName=$3
release=$4

echo "Release version: $release"

# DRY: copys3file.py
bucket=lantern-installers
url=https://s3.amazonaws.com/$bucket/$name
echo "Uploading to http://cdn.getlantern.org/$name..."

if [ $LOCAL_BUILD ] ; then
  echo "Not uploading local build"
else
  aws -putp $bucket $name || die "Could not upload"
  echo "Uploaded lantern to http://cdn.getlantern.org/$name"
  echo "Also available at $url"
fi

if $release ; then
  echo "RELEASING!!!!!"
#  pushd install/$dir || die "Could not change directories"
#  perl -pi -e "s;url_token;$url;g" $newestName || die "Could not replace URL token"

  # Makes sure it actually was replaced
#  grep $url $newestName || die "Something went wrong with creating newest dummy file"

  # Here's the trick -- send a custom mime type that's html instead of the mime type for the file extension
#  aws -putpm $bucket $newestName text/html || die "Could not upload newest?"

#  git checkout $newestName || die "Could not checkout"
#  popd

  echo "Copying on S3 to newest file"
  ./copys3file.py $name || die "Could not copy s3 file to newest!"

  shasum $name | cut -d " " -f 1 > $newestName.sha1

  echo "Uploading SHA-1 `cat $newestName.sha1`"
  aws -putp $bucket $newestName.sha1 || die "Could not upload sha1"

#  md5 -q $name > $newestName.md5
#  echo "Uploading MD5 `cat $newestName.md5`"
#  aws -putp $bucket $newestName.md5

  #cp install/common/lantern.jar $newestName.jar || die "Could not copy newest jar?"
  #pack200 $newestName.pack.gz $newestName.jar || die "Could not pack jar?"

  #echo "Uploading newest jar: $newestName.pack.gz"
  #aws -putp $bucket $newestName.pack.gz
else
  echo "NOT RELEASING!!!"
fi

echo "INSTALLER AVAILABLE AT `pwd`/$name"
