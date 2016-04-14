// es6-promise is required for script to work on older versions of nodejs like
// what comes on old TravisCI build machines.
require('es6-promise').polyfill();

(function () {
  'use strict';
  var gulp = require('gulp');
  var usemin = require('gulp-usemin');
  var uglify = require('gulp-uglify');
  var minifyHtml = require('gulp-minify-html');
  var minifyCss = require('gulp-minify-css');
  var rev = require('gulp-rev');
  var del = require('del');

  gulp.task('usemin', function () {
    return gulp.src('app/index.html')
    .pipe(usemin({
      css: [minifyCss(), 'concat'],
      html: [minifyHtml({empty: true, conditionals: true})],
      js: [rev()],
      js2: [rev()]
    }))
    .pipe(gulp.dest('dist/'));
  });

  gulp.task('copy', function () {
    gulp.src('app/data/*')
    .pipe(gulp.dest('dist/data'));
    gulp.src('app/font/*')
    .pipe(gulp.dest('dist/font'));
    gulp.src('app/locale/*')
    .pipe(gulp.dest('dist/locale'));
    gulp.src('app/img/**/*')
    .pipe(gulp.dest('dist/img'));
    gulp.src('app/partials/*')
    .pipe(gulp.dest('dist/partials'));
  });

  gulp.task('clean', function (cb) {
    del(['dist/'], cb);
  });

  gulp.task('build', ['clean', 'usemin', 'copy'], function() {
    // place code for your default task here
  });
  gulp.task('default', ['build'], function() {
    // place code for your default task here
  });
}());
