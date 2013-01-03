#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

path=`dirname $0`
# Launching lantern only works from within its directory.
cd $path

# make sure required submodules have been initialized
submodules=("lantern-ui")
for i in "${submodules[@]}"
do
  ls $i/.git || die "Were git submodules initialized? (hint: git submodule update --init)"
done

jar=target/lantern*SNAPSHOT.jar

# We need to copy the bouncycastle jar in separately because it's signed. The shaded jar
# include it in the classpath in its manifest.
test -f target/bcprov-jdk16-1.46.jar || cp install/common/bcprov-jdk16-1.46.jar target/
javaArgs="-jar $jar $*"

if [ "$RUN_LANTERN_DEBUG_PORT" ]
    then
    javaArgs="-Xdebug -Xrunjdwp:transport=dt_socket,address=$RUN_LANTERN_DEBUG_PORT,server=y,suspend=y $javaArgs"
fi

uname -a | grep Darwin && extras="-XstartOnFirstThread"

echo "Running using Java on path at `which java` with args $javaArgs"
java $extras $javaArgs || die "Java process exited abnormally"
#java $javaArgs org.lantern.Launcher || die "Java process exited abnormally"
