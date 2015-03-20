module.exports = function(file, blocks, options, push, callback) {
  var path = require('path');
  var gutil = require('gulp-util');
  var Q = require('q');
  var pipeline = require('./pipeline.js');

  var basePath = file.base;
  var name = path.basename(file.path);
  var mainPath = path.dirname(file.path);

  function createFile(name, content) {
    var filePath = path.join(path.relative(basePath, mainPath), name);
    return new gutil.File({
      path: filePath,
      contents: new Buffer(content)
    })
  }

  var html = [];
  var promises = blocks.map(function(block, i) {
    return Q.Promise(function(resolve) {
      if (typeof block == 'string') {
        html[i] = block;
        resolve();
      }
      else if (block.type == 'js') {
        pipeline(block.name, block.files, block.tasks, function(name, file) {
          push(file);
          if (path.extname(file.path) == '.js')
            html[i] = '<script src="' + name.replace(path.basename(name), path.basename(file.path)) + '"></script>';
          resolve();
        }.bind(this, block.nameInHTML));
      }
      else if (block.type == 'css') {
        pipeline(block.name, block.files, block.tasks, function(name, file) {
          push(file);
          html[i] = '<link rel="stylesheet" href="' + name.replace(path.basename(name), path.basename(file.path)) + '"'
            + (block.mediaQuery ? ' media="' + block.mediaQuery + '"' : '') + '/>';
          resolve();
        }.bind(this, block.nameInHTML));
      }
    });
  });

  Q.all(promises).then(function() {
    pipeline(name, [createFile(name, html.join(''))], options && options['html'], function(file) {
      callback(null, file);
    });
  });
};
