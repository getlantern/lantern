#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

mvn --version || die "Please install maven from http://maven.apache.org" 

#pushd ..
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-cocoa-macosx.jar
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86_64 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-cocoa-macosx-x86_64.jar
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.win32.win32 -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-win32-win32-x86.jar
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-gtk-linux-x86.jar
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86_64 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-gtk-linux-x86_64.jar
test -d target || mvn install:install-file -DgroupId=net.sourceforge.jdpapi -DartifactId=jdpapi-java -Dversion=1.0.1 -Dpackaging=jar -Dfile=lib/jdpapi-java-1.0.1.jar
mvn package -Dmaven.test.skip=true || die "Could not package"
#popd

fullPath=`dirname $0`
jar=`find $fullPath/target/*with-dependencies.jar`
cp=`echo $jar | sed 's,./,'$fullPath'/,'`
javaArgs="-jar "$cp" $*"
uname -a | grep Darwin && extras="-XstartOnFirstThread"

echo "Running using Java on path at `which java` with args $javaArgs"
java $extras $javaArgs || die "Java process exited abnormally"
#java $javaArgs org.lantern.Launcher || die "Java process exited abnormally"
