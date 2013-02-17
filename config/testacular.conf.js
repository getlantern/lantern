basePath = '../';

files = [
  JASMINE,
  JASMINE_ADAPTER,

  'app/lib/jquery.js',
  'app/lib/angular/angular.js',
//'app/lib/angular-ui/angular-ui.js',
//'app/lib/select2/select2.js',
  'app/lib/lodash.js',
  'app/lib/jsonpatch.js',

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
