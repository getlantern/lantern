#!/usr/bin/env bash

function die() {
	echo $*
	exit 1
}

if [ $# -ne "2" ] 
then
	die "$0: Received $# args... beta and stable version required"
fi

STABLE=$1
BETA=$2

perl -pi -e "s/STABLE/$STABLE/g" version.js
perl -pi -e "s/BETA/$BETA/g" version.js
s3cmd put -P version.js s3://lantern
