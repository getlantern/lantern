#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ -z "$1" ]
then
    die "Need to specify version string"
fi

#git add cloud.yaml || die "could not add file to git?"
#git commit -m "latest cloud.yaml file" || die "Could not commit cloud.yaml file"
#git push origin master || die "Could not push cloud.yaml"

#echo "Updating template"
#./certstotemplate.py -t cloud.yaml.tmpl -o cloud.yaml || die "Could not create new template"

FILE="cloud.$1.yaml.gz"
echo "Adding $FILE to s3"
gzip -c cloud.yaml > $FILE
s3cmd put -P $FILE s3://lantern_config || die "Could not upload $FILE to s3"

echo "$FILE updated on s3"
