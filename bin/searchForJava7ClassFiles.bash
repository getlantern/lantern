#!/usr/bin/env bash

function die()
{
  echo $*
  exit 1
}

JARS=`find ../lib/repository -name "*.jar"`
for x in $JARS
do
#   echo "Searching for java 7 class files in jar $x"
   mkdir temp
   cp $x temp || die "Could not copy jar $x?"
   cd temp
   jarName=`echo $x | rev | cut -d / -f 1 | rev`
   #echo "jarName $jarName"
   jar xf $jarName

   find . -name "*.class" | xargs file | grep 51 && echo "FOUND JAVA 7 CLASS FILE IN $x"
   cd ..
   rm -rf temp
done
