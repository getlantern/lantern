/*
 * To run this file:
 *  `npm install --dev`
 *  `npm install -g grunt`
 *
 *  `grunt --help`
 */

var fs = require("fs"),
    browserify = require("browserify"),
    pkg = require("./package.json");

module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    uglify: {
      options: {
        banner: "/*\n" + grunt.file.read('LICENSE') + "\n*/"
      },
      dist: {
        files: {
          '<%=pkg.name%>-<%=pkg.version%>.min.js': ['<%=pkg.name%>-<%=pkg.version%>.js']
        }
      }
    }
  });

  grunt.registerTask('build', 'build a browser file', function() {
    var done = this.async();

    var outfile = './color-convert-' + pkg.version + '.js';

    var bundle = browserify('./browser.js').bundle(function(err, src) {
      if (err) throw err;

      console.log("> " + outfile);
      // write sync instead of piping to get around event bug
      fs.writeFileSync(outfile, src);
      done();
    });
  });

  grunt.loadNpmTasks('grunt-contrib-uglify');
};
