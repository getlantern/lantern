#!/usr/bin/env bash

# Amazon credentials are defined in ~/.boto
function die() {
  echo $*
  exit 1
}

which s3cmd || die "You'll need the s3cmd tool to run this. See https://github.com/s3tools/s3cmd and https://github.com/s3tools/s3cmd/blob/master/INSTALL"

baseName="lantern-installer-qa"

bucket="lantern"
#names=($baseName.exe $baseName.dmg $baseName-32-bit.deb $baseName-64-bit.deb)
names=($baseName.exe $baseName.dmg)
#names=($baseName-32-bit.deb $baseName-64-bit.deb)

for name in "${names[@]}"
do
  ext=`echo $name | cut -d . -f 2`
  beta=lantern-installer-beta.$ext

  echo "Copying QA $name to beta $beta"
  s3cmd cp s3://$bucket/$name s3://$bucket/$beta 

  echo "Copying QA sha1 to beta sha1"
  s3cmd cp s3://$bucket/$name.sha1 s3://$bucket/$beta.sha1 
  # Only commit binaries to GitHub if they're not betas
  # echo "Commiting binary to GitHub"
  #./commitbinary.bash $name || die "Could not commit binaries?"
done

echo "Completed moving release from QA to beta!!"
