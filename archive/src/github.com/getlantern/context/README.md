# context [![Travis CI Status](https://travis-ci.org/getlantern/context.svg?branch=master)](https://travis-ci.org/getlantern/context)&nbsp;[![Coverage Status](https://coveralls.io/repos/getlantern/context/badge.png?branch=master)](https://coveralls.io/r/getlantern/context) 

Provides goroutine-based context state inspired by https://github.com/tylerb/gls
and https://github.com/jtolds/gls. It uses the same basic hack as tylerb's
library, but adds a stack abstraction that allows nested contexts similar to
jtolds' library, but using `Enter()` and `Exit()` instead of callback functions.
