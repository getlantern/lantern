#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

fullPath=`dirname $0`
#jar=`find $fullPath/target/*with-dependencies.jar`
jar=`find $fullPath/target/lantern*SNAPSHOT.jar`
cp=`echo $jar | sed 's,./,'$fullPath'/,'`

# We need to copy the bouncycastle jar in separately because it's signed. The shaded jar
# include it in the classpath in its manifest.
cp lib/bcprov-jdk16-1.46.jar target/
javaArgs="-jar "$cp" $*"

if [ "$RUN_LANTERN_DEBUG_PORT" ]
    then
    javaArgs="-Xdebug -Xrunjdwp:transport=dt_socket,address=$RUN_LANTERN_DEBUG_PORT,server=y,suspend=y $javaArgs"
fi

uname -a | grep Darwin && extras="-XstartOnFirstThread"

echo "Running using Java on path at `which java` with args $javaArgs"
java $extras $javaArgs || die "Java process exited abnormally"
#java $javaArgs org.lantern.Launcher || die "Java process exited abnormally"
