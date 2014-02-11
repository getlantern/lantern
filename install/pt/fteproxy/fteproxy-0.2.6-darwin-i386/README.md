fteproxy
========

* homepage: https://fteproxy.org
* source code: https://github.com/kpdyer/fteproxy
* publication: https://eprint.iacr.org/2012/494

Overview
--------

fteproxy provides transport-layer protection to resist keyword filtering, censorship and discrimantory routing policies.
Its job is to relay datastreams, such as web browsing traffic, by encoding the stream into messages that satisfy a user-specified regular expression. 

fteproxy is powered by Format-Transforming Encryption [1] and was presented at CCS 2013.

[1] https://eprint.iacr.org/2012/494

Dependencies
--------

Dependencies for building from source:
* Standard build tools: gcc/g++/make/etc.
* Python 2.7.x: http://python.org/
* GMP 5.1.x: http://gmplib.org/
* re2: https://code.google.com/p/re2/ (included in thirdparty folder)
* PyCrypto 2.6.x: https://www.dlitz.net/software/pycrypto/
* pyptlib 0.0.5: https://gitweb.torproject.org/pluggable-transports/pyptlib.git
* obfsproxy 0.2.4: https://gitweb.torproject.org/pluggable-transports/obfsproxy.git
* Twisted 13.2.x: http://twistedmatrix.com/

Building
-----------

For platform-specific examples of how to install dependencies see: ```BUILDING.[linux|osx|windows]```.

Once all dependencies are installed, it's as simple as:

```
git clone https://github.com/kpdyer/fteproxy.git
cd fteproxy
make
./bin/fteproxy
```

Documentation
-------------

See: https://fteproxy.org/documentation
