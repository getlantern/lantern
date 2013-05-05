#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -ne "5" ]
then
    die "$0: Received $# args... group, artifact, version, file, and sources required"
fi

mvn deploy:deploy-file -DgeneratePom=true -DrepositoryId=aws-release -Durl=s3://lantern-mvn-repo/release -Dpackaging=jar -DgroupId=$1 -DartifactId=$2 -Dversion=$3 -Dfile=$4 -Dsources=$5
#mvn deploy:deploy-file -DgeneratePom=true -DrepositoryId=aws-release -Durl=s3://lantern-mvn-repo/release -Dpackaging=jar -DgroupId=$1 -DartifactId=$2 -Dversion=$3 -Dfile=$4 
