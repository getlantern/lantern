#!/usr/bin/env bash

CONSTANTS_FILE=src/main/java/org/lantern/LanternClientConstants.java
LOCAL_BUILD=false


if [[ $VERSION == "local" ]] || [[ $VERSION == "quick" ]];
then
	export LOCAL_BUILD=true
fi

function die() {
  echo $*
  echo "Reverting constants file"
  git checkout -- $CONSTANTS_FILE || die "Could not revert $CONSTANTS_FILE?"

  # Make sure to move back to master, not tag
  git checkout $oldbranch
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

VERSION=$1
MVN_ARGS=$2
echo "*******MAVEN ARGS*******: $MVN_ARGS"

if [ "$LOCAL_BUILD" = true  ];
then
	echo "Building from local code, not performing git ops"
else
	git pull || die "Could not git pull?"
	if [[ $VERSION == "HEAD" ]]; 
	then 
	    CHECKOUT=HEAD; 
	elif [[ $VERSION == "newest" ]];
	then
	    CHECKOUT=newest;
	else 
	    CHECKOUT=lantern-$VERSION; 
	fi
	
	oldbranch=`git rev-parse --abbrev-ref HEAD`
	
	git checkout $CHECKOUT || die "Could not checkout branch at $CHECKOUT"
fi

if [[ $VERSION == "newest" ]];
then
    # Exporting it so platform-specific scripts will get the right name.
    export VERSION=$(./parseversionfrompom.py);
fi

if [[ $VERSION == "quick" ]];
then
	echo "Skipping maven for quick build"
else
	echo "Version is $VERSION"
	mvn clean || die "Could not clean?"
	mvn $MVN_ARGS -Drelease install -Dmaven.test.skip=true || die "Could not build?"
fi

echo "Reverting constants file"
git checkout -- $CONSTANTS_FILE || die "Could not revert version file?"

if [[ $VERSION == "HEAD" ]] || [[ $VERSION == "local" ]];
then
    cp -f `ls -1t target/lantern-*-small.jar | head -1` install/common/lantern.jar || die "Could not copy jar?"
elif [[ $VERSION == "quick" ]];
then
	cp -f `ls -1t target/lantern-*.jar | head -1` install/common/lantern.jar || die "Could not copy jar?"
else
    cp -f target/lantern-$VERSION-small.jar install/common/lantern.jar || die "Could not copy jar from lantern-$VERSION-small.jar"
fi

cp -f GeoIP.dat install/common/ || die "Could not copy GeoIP.dat?"

./bin/searchForJava7ClassFiles.bash install/common/lantern.jar || die "Found java 7 class files in build!!"

test -f ./install/wrapper/InstallDownloader.class || die "Could not find InstallerDownloader class file?"
file ./install/wrapper/InstallDownloader.class | grep 51 && die "InstallerDownloader.class was compiled with java7"

install4jc -L $INSTALL4J_KEY || die "Could not update license information?"

echo "Moving back to $oldbranch"
git checkout $oldbranch
