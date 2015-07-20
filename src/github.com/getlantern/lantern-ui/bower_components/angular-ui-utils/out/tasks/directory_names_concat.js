/*
 * directory_names_concat
 * Concatenate directory names as dependencies for a AngularJS module.
 * Output a standalone file with : angular.module('$1', [$2]);
 * with $1 the module name,
 * and  $2 a list of dependence..
 */

module.exports = function (grunt) {

  'use strict';

  grunt.registerMultiTask('directory_names_concat', 'Concatenate directory names for a AngularJS module.', function () {

    var module_name = this.data.moduleName || ('x'),
      prefix = this.data.prefix || '';

    this.files.forEach(function (f) {
      var dep = '[\n  ' + f.src.filter(function (filepath) {
        if (!grunt.file.isDir(filepath)) {
          grunt.log.warn('Source file "' + filepath + '" not a directory.');
          return false;
        } else {
          return true;
        }
      }).map(function (filepath) {
          return '"' + prefix + filepath.split('/').pop() + '"';
        }).join(',\n  ') + '\n]';

      // Write the destination file.
      grunt.file.write(f.dest, "angular.module('" + module_name + "',  " + dep + ");");

      grunt.verbose.writeln('Dependencies : ' + dep);

      grunt.log.writeln('File "' + f.dest + '" created.');

    });
  });
};