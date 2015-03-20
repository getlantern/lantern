'use strict';
var path = require('path');
var fs = require('graceful-fs');
var gutil = require('gulp-util');
var map = require('map-stream');
var jsmin = require('jsmin-sourcemap');
var filesize = require('filesize');
var tempWrite = require('temp-write');


module.exports = function () {
	return map(function (file, cb) {
		if (file.isNull()) {
			return cb(null, file);
		}

		if (file.isStream()) {
			return cb(new gutil.PluginError('gulp-jsmin', 'Streaming not supported'));
		}

		if (['.js'].indexOf(path.extname(file.path)) === -1) {
			gutil.log('gulp-jsmin: Skipping unsupported js' + gutil.colors.blue(file.relative));
			return cb(null, file);
		}

		tempWrite(file.contents, path.extname(file.path), function (err, tempFile) {
			if (err) {
				return cb(new gutil.PluginError('gulp-jsmin', err));
			}

			fs.stat(tempFile, function (err, stats) {
				if (err) {
					return cb(new gutil.PluginError('gulp-jsmin', err));
				}

				fs.readFile(tempFile, { encoding : 'UTF-8'}, function(err, data) {
					if (err) {
						return cb(new gutil.PluginError('gulp-jsmin', err));
					}

					var minimized = jsmin({'code': data, 'src': file.relative, 'dist':file.relative + '.min.js'});
					gutil.log('gulp-jsmin:', gutil.colors.green('✔ ') + file.relative); 
					file.contents = new Buffer(minimized.code);
					
					cb(null, file);

				
				});

			});
		});
	});
};
