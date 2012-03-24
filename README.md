README
======

Lantern allows you to give or get access to the internet through other users
around the world connected by a peer-to-peer network.

Lantern is written in Java and runs on modern Mac, Windows, and Linux desktop
systems.

![screenshot](http://www.getlantern.org/static/img/dl-mac_dashboard.png)

To run Lantern from source, you need Maven and Java installed. The Lantern
developers use Oracle's Java 1.6 SDK, but other SDKs may work.

To fetch required submodules, run:

    $ git submodule update --init

and then you can run:

    $ ./run.bash

That's really a "build and run" script that'll grab dependencies, build and
then run Lantern. There's also a `quickRun.bash` script that can run it
when already built.

Lantern's binds its HTTP API to a random port for security. You can pass
`--api-port=xyz` to override this. This is helpful for pointing external
browsers at Lantern for development.

If you want to run Lantern in headless mode, you can pass `--disable-ui`. That
can be useful if you want to just keep Lantern running all the time on a
server, for example.

If you're running Linux, you may need to run one of the following before you
can use the UI, depending on your system:

    sudo apt-get install libxtst6
    sudo yum install xorg-x11-deprecated-libs


Further Reading
---------------

* http://www.getlantern.org
* https://github.com/getlantern/lantern/wiki
* https://github.com/getlantern/lantern/issues
* https://groups.google.com/forum/#!forum/lantern-devel
* https://groups.google.com/forum/#!forum/lantern-users-en

You can also access JavaDocs and automatically generated reports on the Lantern 
codebase at the following:

* http://getlantern.github.com/lantern/
