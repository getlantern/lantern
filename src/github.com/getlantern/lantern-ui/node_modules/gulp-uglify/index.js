'use strict';
var through = require('through2'),
	uglify = require('uglify-js'),
	merge = require('deepmerge'),
	PluginError = require('gulp-util/lib/PluginError'),
	applySourceMap = require('vinyl-sourcemaps-apply'),
	reSourceMapComment = /\n\/\/# sourceMappingURL=.+?$/,
	pluginName = 'gulp-uglify';

function minify(file, options) {
	var mangled;

	try {
		mangled = uglify.minify(String(file.contents), options);
		mangled.code = new Buffer(mangled.code.replace(reSourceMapComment, ''));
		return mangled;
	} catch (e) {
		return createError(file, e);
	}
}

function setup(opts) {
	var options = merge(opts || {}, {
		fromString: true,
		output: {}
	});

	if (options.preserveComments === 'all') {
		options.output.comments = true;
	} else if (options.preserveComments === 'some') {
		// preserve comments with directives or that start with a bang (!)
		options.output.comments = /^!|@preserve|@license|@cc_on/i;
	} else if (typeof options.preserveComments === 'function') {
		options.output.comments = options.preserveComments;
	}

	return options;
}

function createError(file, err) {
	if (typeof err === 'string') {
		return new PluginError(pluginName, file.path + ': ' + err, {
			fileName: file.path,
			showStack: false
		});
	}

	var msg = err.message || err.msg || /* istanbul ignore next */ 'unspecified error';

	return new PluginError(pluginName, file.path + ': ' + msg, {
		fileName: file.path,
		lineNumber: err.line,
		stack: err.stack,
		showStack: false
	});
}

module.exports = function(opt) {

	function uglify(file, encoding, callback) {
		var options = setup(opt);

		if (file.isNull()) {
			return callback(null, file);
		}

		if (file.isStream()) {
			return callback(createError(file, 'Streaming not supported'));
		}

		if (file.sourceMap) {
			options.outSourceMap = file.relative;
		}

		var mangled = minify(file, options);

		if (mangled instanceof PluginError) {
			return callback(mangled);
		}

		file.contents = mangled.code;

		if (file.sourceMap) {
			var sourceMap = JSON.parse(mangled.map);
			sourceMap.sources = [file.relative];
			applySourceMap(file, sourceMap);
		}

		callback(null, file);
	}

	return through.obj(uglify);
};
