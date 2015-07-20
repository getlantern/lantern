/*
 * Copy paste from https://github.com/angular/angular.js/blob/master/src/bootstrap/bootstrap-prettify.js
 * */
angular.module('prettifyDirective', [])
  .factory('reindentCode', function () {
    return function (text, spaces) {
      if (!text) return text;
      var lines = text.split(/\r?\n/);
      var prefix = '      '.substr(0, spaces || 0);
      var i;

      // remove any leading blank lines
      while (lines.length && lines[0].match(/^\s*$/)) lines.shift();
      // remove any trailing blank lines
      while (lines.length && lines[lines.length - 1].match(/^\s*$/)) lines.pop();
      var minIndent = 999;
      for (i = 0; i < lines.length; i++) {
        var line = lines[0];
        var reindentCode = line.match(/^\s*/)[0];
        if (reindentCode !== line && reindentCode.length < minIndent) {
          minIndent = reindentCode.length;
        }
      }

      for (i = 0; i < lines.length; i++) {
        lines[i] = prefix + lines[i].substring(minIndent);
      }
      lines.push('');
      return lines.join('\n');
    }
  })
  .directive('prettyprint', ['reindentCode', function (reindentCode) {
    return {
      restrict: 'C',
      terminal: true,
      compile: function (element) {
        element.html(window.prettyPrintOne(
          reindentCode(element.html()),
          undefined, true));
      }
    };
  }])
;