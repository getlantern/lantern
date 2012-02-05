#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

mvn --version || die "Please install maven from http://maven.apache.org" 

#pushd ..
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-cocoa-macosx.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86_64 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-cocoa-macosx-x86_64.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.win32.win32 -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-win32-win32-x86.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-gtk-linux-x86.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86_64 -Dversion=3.7 -Dpackaging=jar -Dfile=lib/swt-3.7-gtk-linux-x86_64.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=net.sourceforge.jdpapi -DartifactId=jdpapi-java -Dversion=1.0.1 -Dpackaging=jar -Dfile=lib/jdpapi-java-1.0.1.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=com.mcdermottroe.apple -DartifactId=osx-keychain -Dversion=0.1.3 -Dpackaging=jar -Dfile=lib/osxkeychain-0.1.3.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=hexdump -Dversion=0.2 -Dpackaging=jar -Dfile=lib/hexdump-0.2.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=unix-java-x86 -Dversion=0.5 -Dpackaging=jar -Dfile=lib/unix-0.5-x86.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=unix-java-x86_64 -Dversion=0.5 -Dpackaging=jar -Dfile=lib/unix-0.5-x86_64.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=debug -Dversion=1.1 -Dpackaging=jar -Dfile=lib/debug-disable-1.1.jar -DgeneratePom=true
test -d target || mvn install:install-file -DgroupId=org.freedesktop.dbus -DartifactId=dbus-java -Dversion=2.7 -Dpackaging=jar -Dfile=lib/libdbus-java-2.7.jar -DgeneratePom=true

mvn package -Dmaven.test.skip=true || die "Could not package"

./quickRun.bash $*
