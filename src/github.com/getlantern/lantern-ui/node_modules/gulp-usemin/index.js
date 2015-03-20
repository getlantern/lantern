module.exports = function(options) {
  var through = require('through2');
  var gutil = require('gulp-util');
  var blocksBuilder = require('./lib/blocksBuilder.js');
  var htmlBuilder = require('./lib/htmlBuilder.js');

  return through.obj(function(file, enc, callback) {
    if (file.isStream()) {
      this.emit('error', new gutil.PluginError('gulp-usemin', 'Streams are not supported!'));
      callback();
    }
    else if (file.isNull())
      callback(null, file); // Do nothing if no contents
    else {
      try {
        var blocks = blocksBuilder(file, options);
        htmlBuilder(file, blocks, options, this.push.bind(this), callback);
      } catch(e) {
        this.emit('error', e);
        callback();
      }
    }
  });
};
