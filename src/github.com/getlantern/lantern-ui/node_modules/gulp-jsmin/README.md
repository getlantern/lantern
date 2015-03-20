# gulp-jsmin

[![Build Status](https://travis-ci.org/chilijung/gulp-jsmin.png?branch=master)](https://travis-ci.org/chilijung/gulp-jsmin)

minify js using gulp.

## Install

Install with [npm](https://npmjs.org/package/gulp-jsmin)

```
npm install --save-dev gulp-jsmin
```


## Example

```js
var gulp = require('gulp');
var jsmin = require('gulp-jsmin');
var rename = require('gulp-rename');

gulp.task('default', function () {
	gulp.src('src/**/*.js')
		.pipe(jsmin())
		.pipe(rename({suffix: '.min'}))
		.pipe(gulp.dest('dist'));
});
```


## API

### jsmin()

```
jsmin()
```

## License

MIT [@chilijung](http://github.com/chilijung)
