#!/usr/bin/env bash

CONSTANTS_FILE=src/main/java/org/lantern/LanternClientConstants.java

function die() {
  echo $*
  echo "Reverting constants file"
  git checkout -- $CONSTANTS_FILE || die "Could not revert $CONSTANTS_FILE?"

  # Make sure to move back to master, not tag
  git checkout master
  exit 1
}

if [ $# -lt "1" ]
then
    die "$0: Received $# args... version required"
fi

# First make sure we have everything we need to do the install
test -f ../secure/bns-osx-cert-developer-id-application.p12 || die "Need OSX signing certificate at ../secure/bns-osx-cert-developer-id-application.p12"
test -f ../secure/bns_cert.p12 || die "Need windows signing certificate at ../secure/bns_cert.p12"

javac -version 2>&1 | grep 1.7 && die "Cannot build with Java 7 due to bugs with generated class files and pac"

which install4jc || die "No install4jc on PATH -- ABORTING"
printenv | grep INSTALL4J_KEY || die "Must have INSTALL4J_KEY defined with the Install4J license key to use"
printenv | grep INSTALL4J_MAC_PASS || die "Must have OSX signing key password defined in INSTALL4J_MAC_PASS"
printenv | grep INSTALL4J_WIN_PASS || die "Must have windows signing key password defined in INSTALL4J_WIN_PASS"
test -f $CONSTANTS_FILE || die "No constants file at $CONSTANTS_FILE?? Exiting"
GE_API_KEY=`cat lantern_getexceptional.txt`
if [ ! -n "$GE_API_KEY" ]
  then
  die "No API key!!" 
fi

VERSION=$1
MVN_ARGS=$2
echo "*******MAVEN ARGS*******: $MVN_ARGS"

git pull || die "Could not git pull?"
if [[ $VERSION == "HEAD" ]]; 
then 
    CHECKOUT=HEAD; 
else 
    CHECKOUT=lantern-$VERSION; 
fi

git checkout $CHECKOUT || die "Could not checkout branch at $CHECKOUT"

# The build script in Lantern EC2 instances sets this in the environment.
if test -z $FALLBACK_SERVER_HOST; then
    FALLBACK_SERVER_HOST="54.251.192.164";
fi
perl -pi -e "s/fallback_server_host_tok/$FALLBACK_SERVER_HOST/g" $CONSTANTS_FILE || die "Could not set fallback server host"

# The build script in Lantern EC2 instances sets this in the environment.
if test -z $FALLBACK_SERVER_PORT; then
    FALLBACK_SERVER_PORT="11225";
fi
perl -pi -e "s/fallback_server_port_tok/$FALLBACK_SERVER_PORT/g" $CONSTANTS_FILE || die "Could not set fallback server port";

perl -pi -e "s/ExceptionalUtils.NO_OP_KEY/\"$GE_API_KEY\"/g" $CONSTANTS_FILE || die "Could not set exceptional key"

mvn clean || die "Could not clean?"
mvn $MVN_ARGS install -Dmaven.test.skip=true || die "Could not build?"

echo "Reverting constants file"
git checkout -- $CONSTANTS_FILE || die "Could not revert version file?"

if [[ $VERSION == "HEAD" ]];
then
    cp target/lantern-*.jar install/common/lantern.jar || die "Could not copy jar?"
else
    cp target/lantern-$VERSION.jar install/common/lantern.jar || die "Could not copy jar?"
fi


./bin/searchForJava7ClassFiles.bash install/common/lantern.jar || die "Found java 7 class files in build!!"

install4jc -L $INSTALL4J_KEY || die "Could not update license information?"

echo "Moving back to master"
git checkout master 
