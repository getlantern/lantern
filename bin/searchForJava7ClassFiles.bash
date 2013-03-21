#!/usr/bin/env bash

function die() {
  echo $*
  exit 1
}

if [ $# -eq "1" ] 
then
    JARS=( $1 )
    #die "$0: Received $# args... version, whether or not this is a release, architecture, and build ID required"
else 
    JARS=`find ../lib/repository -name "*.jar"`
fi

#JARS=`find ../lib/repository -name "*.jar"`
for x in $JARS
do
#   echo "Searching for java 7 class files in jar $x"
   mkdir temp
   cp $x temp || die "Could not copy jar $x?"
   cd temp
   jarName=`echo $x | rev | cut -d / -f 1 | rev`
   #echo "jarName $jarName"
   jar xf $jarName

   find . -name "*.class" | xargs file | grep 51 && echo "FOUND JAVA 7 CLASS FILE IN $x" && exit 1
   cd ..
   rm -rf temp
done
