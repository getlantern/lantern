var through = require('through2')
  , gutil = require('gulp-util')
	, Minimize = require('minimize');

module.exports = function(opt){
  
  function minimize (file, encoding, callback) {
    if (file.isNull()) {
      return callback(null, file);
    }

    if (file.isStream()) {
      return callback(new gutil.PluginError('gulp-minify-html', 'doesn\'t support Streams'));
    }

    var minimize = new Minimize(opt || {} );  
    minimize.parse(file.contents.toString(), function (err, data) {
      if (err) return callback(new gutil.PluginError('gulp-minify-html', err));

      file.contents = new Buffer(data);
      callback(null, file);
    });
  }

  return through.obj(minimize);
}
