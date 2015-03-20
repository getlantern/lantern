'use strict';
var fs = require('fs');
var assert = require('assert');
var gutil = require('gulp-util');
var jsmin = require('./index');

it('should minify js', function (cb) {
	var stream = jsmin();
	stream.on('data', function (file) {
    assert(file.contents.length < fs.statSync(__dirname + '/sample/test.js').size)
		cb();
	});

	stream.write(new gutil.File({
		path: './sample/test.js',
		contents: fs.readFileSync('./sample/dist/test.min.js')
	}));
});
