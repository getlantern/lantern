(function () {
  'use strict';
  var gulp = require('gulp');
  var compass = require('gulp-compass');
  var usemin = require('gulp-usemin');
  var uglify = require('gulp-uglify');
  var minifyHtml = require('gulp-minify-html');
  var minifyCss = require('gulp-minify-css');
  var rev = require('gulp-rev');
  var livereload = require('gulp-livereload');
  var del = require('del');
  var path = require('path');

  gulp.task('compass', ['clean'], function() {
    gulp.src('app/sass/*.scss')
    .pipe(compass({
      config_file: 'config/compass.rb',
      css: 'app/_css'
    }))
    .pipe(gulp.dest('app/assets/temp'));
  });

  gulp.task('usemin', ['compass', 'clean'], function () {
    return gulp.src('app/index.html')
    .pipe(usemin({
      css: [minifyCss(), 'concat', rev()],
      html: [minifyHtml({empty: true, conditionals: true})],
      libjs: [rev()],
      js: [uglify(), rev()]
    }))
    .pipe(gulp.dest('dist/'));
  });

  gulp.task('copy', ['clean'], function () {
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

  gulp.task('build', ['usemin', 'copy'], function() {
    // place code for your default task here
  });

  //watch
  gulp.task('watch', function() {
    livereload.listen();
    //watch .scss files
    gulp.watch('app/sass/*.scss', ['compass']);
  });

  gulp.task('default', ['watch'], function() {
    // place code for your default task here
  });
}());
