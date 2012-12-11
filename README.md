Lantern [![Build Status](https://secure.travis-ci.org/getlantern/lantern.png)](https://secure.travis-ci.org/getlantern/lantern)
=======

Lantern allows you to give or get access to the internet through other users
around the world connected by a peer-to-peer network.

Lantern is written primarily in Java and runs on modern Mac, Windows, and Ubuntu Linux
desktop systems.

![screenshot](https://www.getlantern.org/static/img/dl-mac_setup.png)


## Setting up a development environment

1. Ensure you have the requirements installed:
  * [git](http://git-scm.com/) (brew install git, port install git-core, etc.)
  * [Java 1.6+](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
  * [Maven](http://maven.apache.org/download.html) (brew install maven, port install maven3, etc.)

2. Clone the repository:

    $ git clone --recursive git://github.com/getlantern/lantern.git 

    or

    $ git clone --recursive git@github.com:getlantern/lantern.git (if you have commit privileges ONLY)   
 
3. Change to the lantern directory:

    $ cd lantern

3. Run the build-and-run script:

    $ ./run.bash

That script will fetch the required libraries, build, and
run Lantern. There's also a `quickRun.bash` script that will run Lantern
when already built.

Lantern binds its HTTP API to a random port for security. You can pass
`--api-port=xyz` to override this. This is helpful for pointing external
browsers at Lantern for development.

If you want to run Lantern in headless mode, pass `--disable-ui`. This
is useful for running Lantern on a server without an X environment.

If you're running Linux, note that Lantern's UI currently targets the
Ubuntu 12.04 desktop environment (i.e. Unity). Other environments may work as
well but are currently untested and unmaintained.

If you want to load the Lantern source code in Eclipse, you can do the following:

1. Build the Eclipse project and classpath files:

    $ mvn eclipse:eclipse

2. Load them into Eclipse using File->Import->General->Existing Projects into Workspace
Select the directory where you ran mvn eclipse:eclipse, and you should see the "lantern" project loaded into Eclipse.

3. Define the "M2_REPO" classpath variable. The steps to do this on OSX are as follows, with other OSes being very similar:
    * Open Eclipse->Preferences->Java->Build Path->Classpath Variables 
    * Hit the "New..." button. 
    * Enter M2_REPO as the name and /Users/YOUR_USER_NAME_HERE/.m2 as the path

That should get Lantern building successfully in Eclipse.

Further Reading
---------------

* https://www.getlantern.org
* https://github.com/getlantern/lantern/wiki
* https://github.com/getlantern/lantern/issues
* https://groups.google.com/forum/#!forum/lantern-devel
* https://groups.google.com/forum/#!forum/lantern-users-en

You can also access JavaDocs and automatically generated reports on the Lantern 
codebase at the following:

* http://getlantern.github.com/lantern/
