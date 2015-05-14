#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ -z "$1" ]
then
    die "Need to specify version string(s), e.g., '$0 default cn'"
fi

for version
do
    FILE="cloud.${version}.yaml"
    echo "Adding $FILE to s3"
    gzip -c $FILE > ${FILE}.gz
    s3cmd put -P ${FILE}.gz s3://lantern_config || die "Could not upload $FILE to s3"
    echo "$FILE.gz updated on s3"
done
