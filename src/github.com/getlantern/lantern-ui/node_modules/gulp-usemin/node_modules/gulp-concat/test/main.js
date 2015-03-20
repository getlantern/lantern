var concat = require('../');
var should = require('should');
var path = require('path');
var assert = require('stream-assert');
var test = require('./test-stream');
var File = require('gulp-util').File;
var gulp = require('gulp');
var sourcemaps = require('gulp-sourcemaps');
require('mocha');

var fixtures = function (glob) { return path.join(__dirname, 'fixtures', glob); }

describe('gulp-concat', function() {
  describe('concat()', function() {
    it('should throw, when arguments is missing', function () {
      (function() {
        concat();
      }).should.throw('Missing file option for gulp-concat');
    });

    it('should ignore null files', function (done) {
      var stream = concat('test.js');
      stream
        .pipe(assert.length(0))
        .pipe(assert.end(done));
      stream.write(new File());
      stream.end();
    });

    it('should emit error on streamed file', function (done) {
      gulp.src(fixtures('*'), { buffer: false })
        .pipe(concat('test.js'))
        .on('error', function (err) {
          err.message.should.eql('Streaming not supported');
          done();
        });
    });

    it('should concat one file', function (done) {
      test('wadap')
        .pipe(concat('test.js'))
        .pipe(assert.first(function (d) { d.contents.toString().should.eql('wadap'); }))
        .pipe(assert.end(done));
    });

    it('should concat multiple files', function (done) {
      test('wadap', 'doe')
        .pipe(concat('test.js'))
        .pipe(assert.length(1))
        .pipe(assert.first(function (d) { d.contents.toString().should.eql('wadap\ndoe'); }))
        .pipe(assert.end(done));
    });

    it('should concatinate buffers', function (done) {
      test([65, 66], [67, 68], [69, 70])
        .pipe(concat('test.js'))
        .pipe(assert.first(function (d) { d.contents.toString().should.eql('AB\nCD\nEF'); }))
        .pipe(assert.end(done));
    });

    it('should preserve mode from files', function (done) {
      test('wadaup')
        .pipe(concat('test.js'))
        .pipe(assert.first(function (d) { d.stat.mode.should.eql(0666); }))
        .pipe(assert.end(done));
    });

    it('should take path from first file', function (done) {
      test('wadap', 'doe')
        .pipe(concat('test.js'))
        .pipe(assert.first(function (newFile) {
          var newFilePath = path.resolve(newFile.path);
          var expectedFilePath = path.resolve('/home/contra/test/test.js');
          newFilePath.should.equal(expectedFilePath);
        }))
        .pipe(assert.end(done));
    });

    it('should preserve relative path from files', function (done) {
      test('wadap', 'doe')
        .pipe(concat('test.js'))
        .pipe(assert.first(function (d) { d.relative.should.eql('test.js'); }))
        .pipe(assert.end(done));
    });

    it('should support source maps', function (done) {
      gulp.src(fixtures('*'))
        .pipe(sourcemaps.init())
        .pipe(concat('all.js'))
        .pipe(assert.first(function (d) {
          d.sourceMap.sources.should.have.length(2);
          d.sourceMap.file.should.eql('all.js');
        }))
        .pipe(assert.end(done));
    });

    it('should not fail if no files were input', function(done) {
      var stream = concat('test.js');
      stream.end();
      done();
    });

    describe('options', function () {
      it('should support newLine', function (done) {
        test('wadap', 'doe')
          .pipe(concat('test.js', {newLine: '\r\n'}))
          .pipe(assert.first(function (d) { d.contents.toString().should.eql('wadap\r\ndoe'); }))
          .pipe(assert.end(done));
      })

      it('should support empty newLine', function (done) {
        test('wadap', 'doe')
          .pipe(concat('test.js', {newLine: ''}))
          .pipe(assert.first(function (d) { d.contents.toString().should.eql('wadapdoe'); }))
          .pipe(assert.end(done));
      })
    });

    describe('with object as argument', function () {
      it('should throw without path', function () {
        (function() {
          concat({ path: undefined });
        }).should.throw('Missing path in file options for gulp-concat');
      });

      it('should create file based on path property', function (done) {
        test('wadap')
          .pipe(concat({path: 'new.txt'}))
          .pipe(assert.first(function (d) { d.path.should.eql('new.txt'); }))
          .pipe(assert.end(done));
      });

      it('should calculate relative path from cwd and path in arguments', function (done) {
        test('wadap')
          .pipe(concat({cwd: '/home/contra', path: '/home/contra/test/new.txt'}))
          .pipe(assert.first(function (d) { d.relative.should.eql('test/new.txt'); }))
          .pipe(assert.end(done));
      });
    });
  });
});
