#!/usr/bin/env bash
function die() {
  echo $*
  exit 1
}

mvn --version || die "Please install maven from http://maven.apache.org" 

#SWT_VERSION=3.7.2
SWT_VERSION=4.2.1
JNA_VERSION=3.4.1
#pushd ..
test -d lantern-ui || git submodule init;git submodule update
mvn install:install-file -DgroupId=net.java.dev.jna -DartifactId=jna -Dversion=$JNA_VERSION -Dpackaging=jar -Dfile=lib/jna-$JNA_VERSION.jar -DgeneratePom=true -Dsources=lib/src/jna-$JNA_VERSION-sources.jar
mvn install:install-file -DgroupId=net.java.dev.jna -DartifactId=platform -Dversion=$JNA_VERSION -Dpackaging=jar -Dfile=lib/platform-$JNA_VERSION.jar -DgeneratePom=true -Dsources=lib/src/jna-$JNA_VERSION-sources.jar
mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86 -Dversion=$SWT_VERSION -Dpackaging=jar -Dfile=lib/swt-$SWT_VERSION-cocoa-macosx.jar -DgeneratePom=true -Dsources=lib/src/org.eclipse.swt.cocoa.macosx.x86_64-$SWT_VERSION-sources.jar
mvn install:install-file -DgroupId=org.eclipse.swt.cocoa -DartifactId=x86_64 -Dversion=$SWT_VERSION -Dpackaging=jar -Dfile=lib/swt-$SWT_VERSION-cocoa-macosx-x86_64.jar -DgeneratePom=true -Dsources=lib/src/org.eclipse.swt.cocoa.macosx.x86_64-$SWT_VERSION-sources.jar
mvn install:install-file -DgroupId=org.eclipse.swt.win32.win32 -DartifactId=x86 -Dversion=$SWT_VERSION -Dpackaging=jar -Dfile=lib/swt-$SWT_VERSION-win32-win32-x86.jar -DgeneratePom=true -Dsources=lib/src/org.eclipse.swt.win32.win32.x86-$SWT_VERSION-sources.jar
mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86 -Dversion=$SWT_VERSION -Dpackaging=jar -Dfile=lib/swt-$SWT_VERSION-gtk-linux-x86.jar -DgeneratePom=true -Dsources=lib/src/org.eclipse.swt.gtk.linux.x86-$SWT_VERSION-sources.jar
mvn install:install-file -DgroupId=org.eclipse.swt.gtk.linux -DartifactId=x86_64 -Dversion=$SWT_VERSION -Dpackaging=jar -Dfile=lib/swt-$SWT_VERSION-gtk-linux-x86_64.jar -DgeneratePom=true -Dsources=lib/src/org.eclipse.swt.gtk.linux.x86-$SWT_VERSION-sources.jar
mvn install:install-file -DgroupId=net.sourceforge.jdpapi -DartifactId=jdpapi-java -Dversion=1.0.1 -Dpackaging=jar -Dfile=lib/jdpapi-java-1.0.1.jar -DgeneratePom=true -Dsources=lib/src/jdpapi-1.0.1-sources.jar
mvn install:install-file -DgroupId=com.mcdermottroe.apple -DartifactId=osx-keychain -Dversion=0.1.5 -Dpackaging=jar -Dfile=lib/osxkeychain-0.1.5.jar -DgeneratePom=true
mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=hexdump -Dversion=0.2 -Dpackaging=jar -Dfile=lib/hexdump-0.2.jar -DgeneratePom=true -Dsources=lib/src/libmatthew-0.8-x86-sources.jar
mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=unix-java-x86 -Dversion=0.5 -Dpackaging=jar -Dfile=lib/unix-0.5-x86.jar -DgeneratePom=true -Dsources=lib/src/libmatthew-0.8-x86-sources.jar
mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=unix-java-x86_64 -Dversion=0.5 -Dpackaging=jar -Dfile=lib/unix-0.5-x86_64.jar -DgeneratePom=true -Dsources=lib/src/libmatthew-0.8-x86_64-sources.jar
mvn install:install-file -DgroupId=cx.ath.matthew -DartifactId=debug -Dversion=1.1 -Dpackaging=jar -Dfile=lib/debug-disable-1.1.jar -DgeneratePom=true -Dsources=lib/src/libmatthew-0.8-x86-sources.jar
mvn install:install-file -DgroupId=org.freedesktop.dbus -DartifactId=dbus-java -Dversion=2.7 -Dpackaging=jar -Dfile=lib/libdbus-java-2.7.jar -DgeneratePom=true
mvn install:install-file -DgroupId=com.barchart.udt -DartifactId=barchart-udt4-bundle -Dversion=1.0.3-SNAPSHOT -Dpackaging=jar -Dfile=lib/barchart-udt4-bundle-1.0.3-SNAPSHOT.jar -DgeneratePom=true
mvn install:install-file -DgroupId=com.barchart.udt -DartifactId=barchart-udt4 -Dversion=1.0.3-SNAPSHOT -Dpackaging=jar -Dfile=lib/barchart-udt4-1.0.3-SNAPSHOT.jar -DgeneratePom=true

