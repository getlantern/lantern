Lantern 
=======

[Build Status](https://getlantern.atlassian.net/builds/browse/LAN-TEST1)

Lantern allows you to give or get access to the internet through other users
around the world connected by a peer-to-peer network.

Lantern is written primarily in Java and runs on modern OS X, Windows, and
Ubuntu Linux desktop systems.

![screenshot](https://raw.github.com/getlantern/lantern-ui/master/screenshots/welcome.png)


## Setting up a development environment

1. Ensure you have the requirements installed:
  * [git](http://git-scm.com/) (brew install git, port install git-core, etc.)
  * [Java 1.6+](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
      * On Windows, make sure to use a 32-bit Java, even if you're running
        64-bit Windows.
      * On Ubuntu, make sure you use **Oracle's JDK and not OpenJDK**.
  * You can install Maven [manually](http://maven.apache.org/download.html) or
    with your package manager: brew install maven, port install maven3, etc.

2. Clone the repository and its submodules with
   `git clone --recursive git://github.com/getlantern/lantern.git`
   or fork first and use your fork's url to be able to commit changes.

   If you have already checked out Lantern but did not pass '--recursive',
   you can clone the submodules with `git submodule update --init`.
 
3. Run the build-and-run script from within the lantern directory:
   `cd lantern; ./run.bash`

That script will fetch the required libraries, build, and
run Lantern. There's also a `quickRun.bash` script that will just run Lantern
once it's already been built.

Lantern binds its HTTP API to a random port and prefix for
security. The port and prefix are chosen at first run.  It can be
found in .lantern/serverAddress

Lantern's UI is developed as a separate project and included inside the lantern
repo as a git submodule. Please see https://github.com/getlantern/lantern-ui
for more.

If you want to run Lantern in headless mode, pass `--disable-ui`. This
is useful for running Lantern on a server without an X environment.

If you're running Linux, note that Lantern's UI currently targets the
Ubuntu 12.04+ desktop environment (i.e. Unity). Other environments may work as
well but are currently untested.

If you want to load the Lantern source code in Eclipse, you can do the following:

1. Build the Eclipse project and classpath files: `mvn eclipse:eclipse`

2. Load them into Eclipse using File->Import->General->Existing Projects into Workspace
   Select the directory where you ran mvn eclipse:eclipse, and you should see
   the "lantern" project loaded into Eclipse.

3. Define the `M2_REPO` classpath variable, e.g.:
    * Open Eclipse->Preferences->Java->Build Path->Classpath Variables 
    * Press "New..."
    * Enter `M2_REPO` as the name and `$HOME/.m2` as the path, where `$HOME`
      is your home directory.

That should get Lantern building successfully in Eclipse.

## Building Installers

As of this writing, the Lantern installers are built using [install4j](http://www.ej-technologies.com/products/install4j/overview.html).  In addition, the installation scripts require an [Exceptional](http://www.exceptional.io) license.  If you want to build installers using the `(deb|osx|win)Install*.bash` scripts, you need to obtain a license of these programs.  Note that this is not required in order to build and run Lantern from source.  

The scripts that build the installers expect the described files in the corresponding paths relative to the lantern base folder:

    # Exceptional license key.
    ./lantern_getexceptional.txt
    # Windows install4j license certificate.
    ../secure/bns_cert.p12
    # OS X install4j license certificate.
    ../secure/bns-osx-cert-developer-id-application.p12

In addition, install4jc expects the following variables defined in the environment:

    INSTALL4J_KEY
    INSTALL4J_MAC_PASS
    INSTALL4J_WIN_PASS


## Building the compressed GeoIp database

java -cp [path-to-lantern-jar] org.lantern.geoip.GeoIpCompressorRunner compress [path-to-GeoLiteCity-csv] src/main/resources/org/lantern/geoip/geoip.db

Further Reading
---------------

* https://www.getlantern.org
* https://github.com/getlantern/lantern/wiki
* https://github.com/getlantern/lantern/issues
* https://github.com/getlantern/lantern-ui
* https://groups.google.com/forum/#!forum/lantern-devel
* https://groups.google.com/forum/#!forum/lantern-users-en

You can also access JavaDocs and automatically generated reports on the Lantern 
codebase at the following:

* http://getlantern.github.com/lantern/
