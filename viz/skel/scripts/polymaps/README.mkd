# Polymaps

Polymaps is a free JavaScript library for making dynamic, interactive maps in
modern web browsers. See <http://polymaps.org> for more details.

This is the `master` branch, which contains the Polymaps source code. If
you're looking for the Polymaps website, you should checkout the `gh-pages`
branch instead.

## Viewing Examples

You'll find lots of Polymaps examples in the suitably-named `examples`
directory. Open any of the HTML files there in your browser to view the
examples, or open them in your text editor of choice to view the source. Most
of the examples are replicated on the [Polymaps website](http://polymaps.org),
though a few of them are only visible locally.

Some of the examples depend on third-party libraries, such as jQuery. These
third-party libraries are not required to use Polymaps but can certainly make
it easier! All third-party libraries should be stored in the `lib` directory,
with an associated `LICENSE` file and optional `README`.

## Filing Bugs

We use GitHub to track issues with Polymaps. You can search for existing
issues, and file new issues, here:

  <http://github.com/simplegeo/polymaps/issues>

You are welcome to file issues either for bugs in the source code, feature
requests, or issues with the Polymaps website.

## Support

If you have questions or problems regarding Polymaps, you can get help by
joining the `#polymaps` IRC channel on irc.freenode.net. You are also welcome
to send GitHub messages or tweets to `mbostock`.

## Build Instructions

You do not need to build Polymaps in order to view the examples; a compiled
copy of Polymaps (`polymaps.js` and `polymaps.min.js`) is included in the
repository.

To edit and build a new version of Polymaps, you must first install Java and
GNU Make. If you are on Mac OS X, you can install Make as part of the UNIX
tools included with
[XCode](http://developer.apple.com/technologies/xcode.html). Once you've setup
your development environment, you can rebuild Polymaps by running the
following command from the repo's root directory:

    make

The Polymaps build process is exceptionally simple. First, all the JavaScript
files are concatenated (using `cat`); the order of files is important to
preserve dependencies. This produces the file `polymaps.js`. Second, this file
is put through Google's [Closure
Compiler](http://code.google.com/closure/compiler/) to minify the JavaScript,
resulting in a smaller `polymaps.min.js`.

If you are doing development, it is highly recommended that you use the
non-minified JavaScript for easier debugging. The minified JavaScript is only
intended for production, where file size matters. Note that the development
version is marked as read-only so that you don't accidentally overwrite your
edits after a re-build.
