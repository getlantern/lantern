#!/usr/bin/env bash

# This is a script for automatically deploying the GData jars to the LittleShoot
# maven repository. 

gdataVersion=$1

function die() {
    rm -rf $gdataVersion
    echo $*
    exit 1
}

me=`basename $0`

if [ $# -ne 1 ]
then
  "Should be a single GData version argument, as in './$me 2.2.1-alpha'. For versions, see: http://gdata-java-client.googlecode.com/svn/tags/"
  exit 1
fi


echo "Checking out GData version $gdataVersion"
svn co http://gdata-java-client.googlecode.com/svn/tags/$gdataVersion || die "Could not checkout SVN"

pushd $gdataVersion/gdata || die "Could not move to gdata base dir"
ant dist || die "Could not build with ant"
cd build-bin/dist/ || die "Could not cd to dist directory"

mvn deploy:deploy-file -DgroupId=com.google.gdata -DartifactId=gdata -Dversion=$gdataVersion -Dfile=gdata-$gdataVersion.jar -Dpackaging=jar -DgeneratePom=true -Durl=scpexe://dev.littleshoot.org/var/maven -DrepositoryId=littleshoot || die "Could not deploy file"

echo "Cleaning up"
popd
rm -rf $gdataVersion
