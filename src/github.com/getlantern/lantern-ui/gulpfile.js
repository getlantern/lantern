(function () {
  'use strict';
  var console = require('console');
  var gulp = require('gulp');
  var compass = require('gulp-compass');
  var usemin = require('gulp-usemin');
  var uglify = require('gulp-uglify');
  var minifyHtml = require('gulp-minify-html');
  var minifyCss = require('gulp-minify-css');
  var rev = require('gulp-rev');
  var livereload = require('gulp-livereload');
  var ngConfig = require('gulp-ng-config');
  var del = require('del');
  var fs = require('fs');
  var raml_mock = require('raml-mocker-server');

  var scssGlob = 'app/scss/*.scss';

  gulp.task('compass', function() {
    gulp.src(scssGlob)
    .pipe(compass({
      config_file: 'config/compass.rb',
      css: 'app/_css'
    }));
  });

  gulp.task('usemin', ['compass', 'dist-env', 'clean'], function () {
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

  gulp.task('mock', function() {
    fs.access('pro-spec', function(err) {
      if (err) {
        console.log('please `ln -s` pro-spec folder first!');
      } else {
        raml_mock({
          path: "pro-spec",
          port: 3030,
          debug: true,
          watch: true
        });
      }
    });
  });

  gulp.task('dev-env', function() {
    gulp.src('config/env.json')
    .pipe(ngConfig('app.constants', {
      environment: 'dev',
      createModule: false
    }))
    .pipe(gulp.dest('app/js/'));
  });

  gulp.task('dist-env', function() {
    gulp.src('config/env.json')
    .pipe(ngConfig('app.constants', {
      environment: 'dist',
      createModule: false
    }))
    .pipe(gulp.dest('app/js/'));
  });

  gulp.task('watch', function() {
    livereload.listen();
    //watch .scss files
    gulp.watch(scssGlob, ['compass']);
  });

  gulp.task('default', ['watch', 'dev-env', 'mock'], function() {
    // place code for your default task here
  });
}());
