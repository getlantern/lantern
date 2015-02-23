
v0.4.3 / 2014-07-31
==================

 * fix res.Body.Close() defer

v0.4.2 / 2014-07-31
==================

 * remove implicit newline in .Write()

v0.4.1 / 2014-07-31
==================

 * fix when no tags are used

v0.4.0 / 2014-07-25
==================

 * add tag support to New()
 * add varg support to .Tag()

v0.3.0 / 2014-07-25
==================

 * add io.Writer interface support
 * add tag support. Closes #5
 * change User-Agent sent to loggly to match repo

0.1.1 / 2014-07-10
==================

 * fix: close the response body so it doesn't leak file descriptors

0.3.0 / 2014-06-01
==================

 * change timestamp to be milliseconds

0.2.0 / 2014-05-31
==================

 * add .Stdout option
 * add simple example
 * fix locking typo
 * refactor locking

0.1.0 / 2014-05-22
==================

 * replace Debugging option with debug package

0.0.5 / 2014-05-20
==================

 * add mutexes

0.0.4 / 2014-05-20
==================

 * rename .Log() to .Send()

0.0.3 / 2014-05-20
==================

 * unix epoch timestamp

0.0.2 / 2014-05-20
==================

 * https
