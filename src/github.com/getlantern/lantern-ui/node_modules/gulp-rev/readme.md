# gulp-rev [![Build Status](https://travis-ci.org/sindresorhus/gulp-rev.svg?branch=master)](https://travis-ci.org/sindresorhus/gulp-rev)

> Static asset revisioning by appending content hash to filenames
`unicorn.css` → `unicorn-098f6bcd.css`

Make sure to set the files to [never expire](http://developer.yahoo.com/performance/rules.html#expires) for this to have an effect.


## Install

```
$ npm install --save-dev gulp-rev
```


## Usage

```js
var gulp = require('gulp');
var rev = require('gulp-rev');

gulp.task('default', function () {
	return gulp.src('src/*.css')
		.pipe(rev())
		.pipe(gulp.dest('dist'));
});
```


## API

### rev()

### rev.manifest([path], [options])

#### path

Type: `string`  
Default: `"rev-manifest.json"`

Manifest file path.

#### options

##### base

Type: `string`  
Default: `process.cwd()`

Override the `base` of the manifest file.

##### cwd

Type: `string`  
Default: `process.cwd()`

Override the `cwd` (current working directory) of the manifest file.

##### merge

Type: `boolean`  
Default: `false`

Merge existing manifest file.


### Original path

Original file paths are stored at `file.revOrigPath`. This could come in handy for things like rewriting references to the assets.


### Asset hash

The hash of each rev'd file is stored at `file.revHash`. You can use this for customizing the file renaming, or for building different manifest formats.


### Asset manifest

```js
var gulp = require('gulp');
var rev = require('gulp-rev');

gulp.task('default', function () {
	// by default, gulp would pick `assets/css` as the base,
	// so we need to set it explicitly:
	return gulp.src(['assets/css/*.css', 'assets/js/*.js'], {base: 'assets'})
		.pipe(gulp.dest('build/assets'))  // copy original assets to build dir
		.pipe(rev())
		.pipe(gulp.dest('build/assets'))  // write rev'd assets to build dir
		.pipe(rev.manifest())
		.pipe(gulp.dest('build/assets')); // write manifest to build dir
});
```

An asset manifest, mapping the original paths to the revisioned paths, will be written to `build/assets/rev-manifest.json`:

```json
{
	"css/unicorn.css": "css/unicorn-098f6bcd.css",
	"js/unicorn.js": "js/unicorn-273c2cin.js"
}
```

By default, `rev-manifest.json` will be replaced as a whole. To merge with an existing manifest, pass `merge: true` and the output destination (as `base`) to `rev.manifest()`:

```js
var gulp = require('gulp');
var rev = require('gulp-rev');

gulp.task('default', function () {
	// by default, gulp would pick `assets/css` as the base,
	// so we need to set it explicitly:
	return gulp.src(['assets/css/*.css', 'assets/js/*.js'], {base: 'assets'})
		.pipe(gulp.dest('build/assets'))
		.pipe(rev())
		.pipe(gulp.dest('build/assets'))
		.pipe(rev.manifest({
			base: 'build/assets',
			merge: true // merge with the existing manifest (if one exists)
		}))
		.pipe(gulp.dest('build/assets'));
});
```

You can optionally call `rev.manifest('manifest.json')` to give it a different path or filename.


## Sourcemaps and `gulp-concat`

Because of the way `gulp-concat` handles file paths, you may need to set `cwd` and `path` manually on your `gulp-concat` instance to get everything to work correctly:

```js
var gulp = require('gulp');
var rev = require('gulp-rev');
var sourcemaps = require('gulp-sourcemaps');
var concat = require('gulp-concat');

gulp.task('default', function () {
	return gulp.src('src/*.js')
		.pipe(sourcemaps.init())
		.pipe(concat({path: 'bundle.js', cwd: ''}))
		.pipe(rev())
		.pipe(sourcemaps.write('.'))
		.pipe(gulp.dest('dist'));
```


## Streaming

This plugin does not support streaming. If you have files from a streaming source, such as browserify, you should use [gulp-buffer](https://github.com/jeromew/gulp-buffer) before `gulp-rev` in your pipeline:

```js
var gulp = require('gulp');
var browserify = require('browserify');
var source = require('vinyl-source-stream');
var buffer = require('gulp-buffer');
var rev = require('gulp-rev');

gulp.task('default', function () {
	return browserify('src/index.js')
		.bundle({debug: true})
		.pipe(source('index.min.js'))
		.pipe(buffer())
		.pipe(rev())
		.pipe(gulp.dest('dist'))
});
```


## Integration

For more info on how to integrate **gulp-rev** into your app, have a look at the [integration guide](integration.md).


## Works with gulp-rev

- [gulp-rev-replace](https://github.com/jamesknelson/gulp-rev-replace) - Rewrite occurences of filenames which have been renamed
- [gulp-rev-css-url](https://github.com/galkinrost/gulp-rev-css-url) - Override URLs in CSS files with the revved ones
- [gulp-rev-outdated](https://github.com/shonny-ua/gulp-rev-outdated) - Old static asset revision files filter
- [gulp-rev-collector](https://github.com/shonny-ua/gulp-rev-collector) - Static asset revision data collector
- [rev-del](https://github.com/callumacrae/rev-del) - Delete old unused assets


## License

MIT © [Sindre Sorhus](http://sindresorhus.com)
