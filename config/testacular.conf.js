basePath = '../';

files = [
  JASMINE,
  JASMINE_ADAPTER,
  'app/lib/angular/docs/js/jquery.js',
  'app/lib/angular/angular.js',
  'app/lib/angular/angular-*.js',
  'app/lib/angular-ui/angular-ui.js',
  'app/lib/bootstrap/js/bootstrap.js',
  'app/lib/select2/select2.js',
  'app/lib/*.js',
  'test/lib/angular/angular-mocks.js',
  'app/js/**/*.js',
  'test/unit/**/*.js'
];

autoWatch = true;

browsers = ['Chrome'];

junitReporter = {
  outputFile: 'test_out/unit.xml',
  suite: 'unit'
};
