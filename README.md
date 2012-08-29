README
======

Lantern allows you to give or get access to the internet through other users
around the world connected by a peer-to-peer network.

Lantern is written in Java and runs on modern Mac, Windows, and Ubuntu Linux
desktop systems.

![screenshot](https://www.getlantern.org/static/img/dl-mac_setup.png)

To run Lantern from source, you need Maven and Java installed. To install maven on OSX with MacPorts installed, you can run:

```
sudo port install maven3
```

The source code is compatible with Java 1.6 and above.

Then you can run:

```
$ ./run.bash
```
That's actually a "build and run" script that'll grab dependencies, build and
then run Lantern. There's also a `quickRun.bash` script that will just run it
when already built.

Lantern binds its HTTP API to a random port for security. You can pass
`--api-port=xyz` to override this. This is helpful for pointing external
browsers at Lantern for development.

If you want to run Lantern in headless mode, you can pass `--disable-ui`. That
can be useful if you want to just keep Lantern running all the time on a
server, for example.

If you're running Linux, note that Lantern's UI currently targets the
Ubuntu 12.04 desktop environment (i.e. Unity). Other environments may work as
well but are untested and unmaintained.


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
