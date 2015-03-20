var gulp = require('gulp');
var jsmin = require('./');
var rename = require('gulp-rename');

gulp.task('default', function () {
    gulp.src('./sample/test.js')
        .pipe(jsmin())
				.pipe(rename({suffix: '.min'}))
        .pipe(gulp.dest('./sample/dist'));
});
