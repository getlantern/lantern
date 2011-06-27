#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

#pushd ..
mvn -o package -Dmaven.test.skip=true || die "Could not package"
#popd

fullPath=`dirname $0`
jar=`find $fullPath/target/*with-dependencies.jar`
cp=`echo $jar | sed 's,./,'$fullPath'/,'`
javaArgs="-jar "$cp" $*"

echo "Running using Java on path at `which java` with args $javaArgs"
java $javaArgs || die "Java process exited abnormally"
#java $javaArgs org.lantern.Launcher || die "Java process exited abnormally"
