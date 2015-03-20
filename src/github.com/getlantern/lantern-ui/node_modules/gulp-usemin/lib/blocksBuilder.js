var fs = require('fs');
var glob = require('glob');
var path = require('path');
var gutil = require('gulp-util');

module.exports = function(file, options) {
  options = options || {};

  var startReg = /<!--\s*build:(\w+)(?:(?:\(([^\)]+?)\))?\s+(\/?([^\s]+?))?)?\s*-->/gim;
  var endReg = /<!--\s*endbuild\s*-->/gim;
  var jsReg = /<\s*script\s+.*?src\s*=\s*("|')([^"']+?)\1.*?><\s*\/\s*script\s*>/gi;
  var cssReg = /<\s*link\s+.*?href\s*=\s*("|')([^"']+)\1.*?>/gi;
  var cssMediaReg = /<\s*link\s+.*?media\s*=\s*("|')([^"']+)\1.*?>/gi;
  var startCondReg = /<!--\[[^\]]+\]>/gim;
  var endCondReg = /<!\[endif\]-->/gim;

  var basePath = file.base;
  var mainPath = path.dirname(file.path);
  var content = String(file.contents);
  var sections = content.split(endReg);
  var blocks = [];
  var cssMediaQuery = null;

  function getFiles(content, reg, alternatePath) {
    var paths = [];
    var files = [];
    cssMediaQuery = null;

    content
      .replace(startCondReg, '')
      .replace(endCondReg, '')
      .replace(/<!--(?:(?:.|\r|\n)*?)-->/gim, function (a) {
        return options.enableHtmlComment ? a : '';
      })
      .replace(reg, function (a, quote, b) {
        var filePath = path.resolve(path.join(alternatePath || options.path || mainPath, b));

        if (options.assetsDir)
          filePath = path.resolve(path.join(options.assetsDir, path.relative(basePath, filePath)));

        paths.push(filePath);
      });

    if (reg === cssReg) {
      content.replace(cssMediaReg, function(a, quote, media) {
        if (!cssMediaQuery) {
          cssMediaQuery = media;
        } else {
          if (cssMediaQuery != media)
            throw new gutil.PluginError('gulp-usemin', 'incompatible css media query for ' + a + ' detected.');
        }
      });
    }

    for (var i = 0, l = paths.length; i < l; ++i) {
      var filepaths = glob.sync(paths[i]);
      if(filepaths[0] === undefined) {
        throw new gutil.PluginError('gulp-usemin', 'Path ' + paths[i] + ' not found!');
      }
      filepaths.forEach(function (filepath) {
        files.push(new gutil.File({
          path: filepath,
          contents: fs.readFileSync(filepath)
        }));
      });
    }

    return files;
  }

  for (var i = 0, l = sections.length; i < l; ++i) {
    if (sections[i].match(startReg)) {
      var section = sections[i].split(startReg);

      blocks.push(section[0]);

      var startCondLine = section[5].match(startCondReg);
      var endCondLine = section[5].match(endCondReg);
      if (startCondLine && endCondLine)
        blocks.push(startCondLine[0]);

      if (section[1] !== 'remove') {
        if (jsReg.test(section[5])) {
          blocks.push({
            type: 'js',
            nameInHTML: section[3],
            name: section[4],
            files: getFiles(section[5], jsReg, section[2]),
            tasks: options[section[1]]
          });
        } else {
          blocks.push({
            type: 'css',
            nameInHTML: section[3],
            name: section[4],
            files: getFiles(section[5], cssReg, section[2]),
            tasks: options[section[1]],
            mediaQuery: cssMediaQuery
          });
        }
      }

      if (startCondLine && endCondLine)
        blocks.push(endCondLine[0]);
    } else
      blocks.push(sections[i]);
  }

  return blocks;
};
