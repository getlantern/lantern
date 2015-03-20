# env-variable

A cross platform `env-variable` for browsers and node. Of course, browsers
doesn't have environment variables but we do have hashtags and localStorage
which we will use as fallback.

### hashtags

This is a really easy way of adding some trigger some environment variables that
you might use for debugging. We assume that the hashtag (#) contains
a query string who's key is the name and the value.. the value.

### localStorage

If you want more persisting env variables you can set a query string of env
variables in localStorage. It will attempt to use the `env` variable.

## Installation

This module is written for node and browserify and can be installed using npm:

```
npm install --save env-variable
```

## Usage

This module exposes a node / `module.exports` interface. 

```js
var env = require('env-variable')();
```

As you can see from the example above we execute the required module. You can
alternately store it but I don't assume this a common pattern. When you execute
the function it returns an object with all the env variables. 

When you execute the function you can alternately pass it an object which will
be seen as the default env variables and all fallbacks and `process.env` will be
merged in to this object.

```js
var env = require('env-variable')({
  foo: 'bar',
  NODE_ENV: 'production'
});
```

Oh, in `env-variable` we don't really care how you write your env variables. We
automatically add an extra lower case version of the variables so you can access
everything in one consistent way.

And that's basically everything you need to know. *random high fives*.

## License

MIT
