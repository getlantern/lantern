basePath = '../';

files = [
  JASMINE,
  JASMINE_ADAPTER,

  'app/components/jquery/jquery.js',
  'app/components/angular/angular.js',
  'app/components/lodash/lodash.js',
  'app/components/jsonpatch/jsonpatch.min.js',

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
