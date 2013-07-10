basePath = '../';

files = [
  JASMINE,
  JASMINE_ADAPTER,

  'app/bower_components/jquery/jquery.js',
  'app/bower_components/angular/angular.js',
  'app/bower_components/lodash/lodash.js',
  'app/bower_components/jsonpatch/jsonpatch.min.js',

  'app/js/*.js',

  'test/lib/angular/angular-mocks.js',
  'test/unit/**/*.js'
];

autoWatch = true;

browsers = ['Chrome'];

junitReporter = {
  outputFile: 'test_out/unit.xml',
  suite: 'unit'
};
