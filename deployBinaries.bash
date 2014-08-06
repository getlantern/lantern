#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "3" ]
then
    die "$0: Received $# args... dir, name, name of newest file (newest.dmg), and whether this is a release version required"
fi
name=$1
newestName=$2
release=$3

echo "Release version: $release"

# DRY: copys3file.py
bucket=lantern
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
  ./copys3file.py $name $newestName || die "Could not copy s3 file to newest!"

  shasum $name | cut -d " " -f 1 > $newestName.sha1

  echo "Uploading SHA-1 `cat $newestName.sha1`"
  aws -putp $bucket $newestName.sha1 || die "Could not upload sha1"

  bindir=../lantern-binaries
  echo "Copying binaries to $bindir" 
  test -d $bindir || die "No $bindir repo to deploy binaries to?"
  cp $newestName.sha1 $bindir/$name.sha1 || die "Could not copy $newestName.sha1 to $bindir/$name.sha1?"
  cp $newestName.sha1 $bindir || die "Could not copy $newestName.sha1 to $bindir?"
  cp $name $bindir || die "Could not copy $name to $bindir?"
  cp $name $bindir/$newestName || die "Could not copy $name to $bindir/$newestName?"

  pushd $bindir || die "Could not move to binary repo?"
  git add *
  git commit -m "Latest binaries for $name" || die "Could not commit $name?"
  git push origin master || die "Could not push?" 
  popd
  
  
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
