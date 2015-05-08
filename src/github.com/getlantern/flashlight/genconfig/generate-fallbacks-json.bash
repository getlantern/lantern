#!/bin/bash

function die() {
  echo $*
  exit 1
}

[ -n "${production_cloudmaster_IP}" ] || die "You need to set the production_cloudmaster_IP environment variable."

locales=("nl" "jp")

for locale in "${locales[@]}"
do
    echo "Generating list for ${locale} ..."
    ssh $production_cloudmaster_IP "sudo regenerate-fallbacks-list ${locale}" > ${locale}.fallbacks.json || die "Error generating fallbacks list.  Is your id_rsa.pub uploaded to the cloudmaster?"
done

echo "Done."
