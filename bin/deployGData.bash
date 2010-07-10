#!/usr/bin/env bash

# This is a script for automatically deploying the GData jars to the LittleShoot
# maven repository. 

function die() {
    echo $*
    exit 1
}

if [ $# -ne 1 ]
then
  die "Should be a single GData version argument, as in '2.2.1-alpha'. For versions, see: http://gdata-java-client.googlecode.com/svn/tags/"
fi

echo "First argument should be of the form '2.2.1-alpha', for example"
gdataVersion=$1
gdataBase=~/code/google/gdata-svn/$gdataVersion

echo "Checking out GData version $gdataVersion"
svn co http://gdata-java-client.googlecode.com/svn/tags/$gdataVersion $gdataBase || die "Could not checkout SVN"

cd $gdataBase/gdata || die "Could not move to gdata base dir"
ant dist || die "Could not build with ant"
cd build-bin/dist/ || die "Could not cd to dist directory"

mvn deploy:deploy-file -DgroupId=com.google.gdata -DartifactId=gdata -Dversion=$gdataVersion -Dfile=gdata-$gdataVersion.jar -Dpackaging=jar -DgeneratePom=true -Durl=scpexe://dev.littleshoot.org/var/maven -DrepositoryId=littleshoot || die "Could not deploy file"
