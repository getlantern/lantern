#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

fullPath=`dirname $0`
jar=`find $fullPath/target/*with-dependencies.jar`
cp=`echo $jar | sed 's,./,'$fullPath'/,'`
javaArgs="-jar "$cp" $*"

if [ "$RUN_LANTERN_DEBUG_PORT" ]
    then
    javaArgs="-Xdebug -Xrunjdwp:transport=dt_socket,address=$RUN_LANTERN_DEBUG_PORT,server=y,suspend=y $javaArgs"
fi

uname -a | grep Darwin && extras="-XstartOnFirstThread"

echo "Running using Java on path at `which java` with args $javaArgs"
java $extras $javaArgs || die "Java process exited abnormally"
#java $javaArgs org.lantern.Launcher || die "Java process exited abnormally"
