var gulp = require('gulp');
var uglify = require('gulp-uglify');
var concat = require('gulp-concat');
var karma = require('karma').server;
var jasmine = require('gulp-jasmine');

gulp.task('default', ["minify", "test"]);

gulp.task('minify', function () {
    gulp.src('re-tree.js')
        .pipe(uglify())
        .pipe(concat("re-tree.min.js"))
        .pipe(gulp.dest('.'));
});

/**
 * Run test once and exit
 */
gulp.task('test', ['test client', 'test server']);

gulp.task('test client', function (done) {
    karma.start({
        configFile: __dirname + '/karma.conf.js',
        singleRun: true
    }, done);
});

gulp.task('test server', function () {
    return gulp.src('test/server.js')
        .pipe(jasmine());
});

gulp.task('watch', [], function () {
    gulp.watch(["**/*.js"], ["test", "minify"]);
});
