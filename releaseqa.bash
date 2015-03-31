#!/usr/bin/env bash

# Amazon credentials are defined in ~/.boto
function die() {
  echo $*
  exit 1
}

if [ $# -ne "1" ]
then
  die "$0: Received $# args, expected the tag name, as in 2.0.0-beta3'"
fi

TAG=$1


which s3cmd || die "You'll need the s3cmd tool to run this. See https://github.com/s3tools/s3cmd and https://github.com/s3tools/s3cmd/blob/master/INSTALL"


./createrelease.rb getlantern flashlight-build $TAG || die "Could not create release"
./tagandbuild.bash $TAG || die "Could not tag and build"

baseName="lantern-installer-qa"
cp lantern-installer.exe $baseName.exe || die "Could not copy windows executable?"
cp Lantern.dmg $baseName.dmg || die "Could not copy OSX dmg?"
test -f $baseName.dmg || mv Lantern.dmg $baseName.dmg || die "Could not rename dmg?"

bucket="lantern"
#names=($baseName.exe $baseName.dmg $baseName-32-bit.deb $baseName-64-bit.deb)
names=($baseName.exe $baseName.dmg)
#names=($baseName-32-bit.deb $baseName-64-bit.deb)

for name in "${names[@]}"
do
  shasum $name | cut -d " " -f 1 > $name.sha1
  echo "Uploading SHA-1 `cat $name.sha1`"
  s3cmd put -P $name.sha1 s3://$bucket
  echo "Uploading $name to S3"
  s3cmd put -P $name s3://$bucket

  ext=`echo $name | cut -d . -f 2`
  versioned=lantern-installer-$TAG.$ext

  echo "Copying $versioned"
  s3cmd cp s3://$bucket/$name s3://$bucket/$versioned 

  # Only commit binaries to GitHub if they're not betas
  # echo "Commiting binary to GitHub"
  #./commitbinary.bash $name || die "Could not commit binaries?"
done

bzip2 --force lantern_windows_386.exe || die "Could not compress windows"
bzip2 --force lantern_darwin_amd64 || die "Could not compress osx"

echo "Uploading Windows binary for auto-updates"
./uploadghasset.rb $TAG lantern_windows_386.exe.bz2 || die "Could not upload windows binary?" 

echo "Uploading OSX binary for auto-updates"
./uploadghasset.rb $TAG lantern_darwin_amd64.bz2 || die "Could not upload OSX binary?" 


echo "Completed publishing latest binaries!!"
