/* jshint node:true */

'use strict';

var gulp = require('gulp');
var jshint = require('gulp-jshint');
var mocha = require('gulp-mocha');

gulp.task('lint', function() {
	return gulp.src('test/main.js')
		.pipe(jshint())
		.pipe(jshint.reporter('default'))
		.pipe(mocha());
});

gulp.task('default', ['lint']);