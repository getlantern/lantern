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
    die "$0: Received $# args, expected base name and generic installer base name, as in 'lantern-1.0.0-beta7-789a299 lantern-installer'"
fi

which s3cmd || die "You'll need the s3cmd tool to run this. See https://github.com/s3tools/s3cmd and https://github.com/s3tools/s3cmd/blob/master/INSTALL"
baseName=$1
bucket="lantern"
names=($baseName.exe $baseName.dmg $baseName-32-bit.deb $baseName-64-bit.deb)
#names=($baseName.exe $baseName.dmg)
#names=($baseName-32-bit.deb $baseName-64-bit.deb)
tag=${baseName:0:${#baseName}-8}
newest=$2

bindir=../lantern-binaries
pushd $bindir || die "Could not go to binaries directory?"

// Totally overwrite git to avoid keeping history for large binaries
test -d .git && rm -rf .git || die "Could not delete .git repo?"
rm -rf lantern*
rm -rf latest*

git init || die "Could not create git repo?"

popd
#echo "Pulling latest to make sure we can push"
#git pull || die "Could not pull latest?"

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


  # TODO: DO ALL THIS IN THE PYTHON SCRIPT
  shasum $name | cut -d " " -f 1 > $newestName.sha1
  echo "Uploading SHA-1 `cat $newestName.sha1`"
  s3cmd put -P $newestName.sha1 s3://$bucket

  ./commitbinary.bash $name $newestName || die "Could not commit binaries?"
done

cd $bindir || die "Could not change to binaries directory?"

git remote add origin "git@github.com:getlantern/lantern-binaries.git" || die
"Could not add origin git@github.com:getlantern/lantern-binaries.git?"
git push -u --force origin master || die "Could not force push new binaries?"


echo "Updating version file"
version=`echo $baseName | cut -d - -f 2`

# Note this needs to change when we add the beta channel
./uploadversion.bash $version $version
echo "Completed publishing latest binaries!!"



