[Godoc](http://godoc.org/github.com/getlantern/elevate)

elevate currently only works for OS X and Windows. The Windows support
currently uses a Visual Basic script that ends up displaying a confusing prompt
and is generally hoaky - it will be replaced by a C++ program that does the same
thing but with a better prompt.

On OS X, it uses cocoasudo from here - https://github.com/getlantern/cocoasudo,
forked from https://github.com/kalikaneko/cocoasudo to explicitly support OSX
10.6.
